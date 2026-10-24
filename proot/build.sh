#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds libproot.so and libproot_loader.so from Termux's proot plus patches/, with
# Termux's package options. Writes them, SHA256SUMS and the source tarball to <out-dir>.
# Usage: NDK=<Android NDK r28c> proot/build.sh <out-dir>
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mkdir -p "$1" && cd "$1" && pwd)
: "${NDK:?set NDK to the Android NDK root}"
. "$HERE/deps.env"

grep -q "^Pkg.Revision = $NDK_REVISION\$" "$NDK/source.properties" \
    || { echo "NDK must be $NDK_REVISION" >&2; exit 1; }
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

# A proot-*-sb* tag gives the release version; anything else is marked -dev.
if [[ -z "${PROOT_VERSION:-}" ]]; then
    if tag=$(git -C "$HERE" describe --tags --exact-match --match 'proot-*-sb*' 2>/dev/null); then
        PROOT_VERSION=${tag#proot-}
    else
        PROOT_VERSION="${PROOT_UPSTREAM_TAG#v}-sb-dev"
    fi
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fetch_deb() {
    curl -fsSL --retry 3 -o "$WORK/$1" "$DEBS_BASE/$1"
    echo "$2  $WORK/$1" | sha256sum -c --quiet -
    (cd "$WORK" && ar p "$1" data.tar.xz | tar -xJ --strip-components=5 -C deps)
}
mkdir -p "$WORK/deps"
fetch_deb "$TALLOC_DEB" "$TALLOC_SHA256"
fetch_deb "$SHMEM_DEB" "$SHMEM_SHA256"
# The APK ships talloc as libtalloc2.so. Renaming the input's SONAME makes the linker
# record that name, without patching the output.
patchelf --set-soname libtalloc2.so "$WORK/deps/usr/lib/libtalloc.so.2.4.3"

# Upstream at the pinned commit, plus our patches. A fixed path and -ffile-prefix-map
# keep the build reproducible.
SRCNAME=proot-$PROOT_VERSION
git clone -q "$PROOT_REPO" "$WORK/$SRCNAME"
git -C "$WORK/$SRCNAME" checkout -q "$PROOT_UPSTREAM_COMMIT"
git -C "$WORK/$SRCNAME" apply "$HERE"/patches/*.patch
rm -rf "$WORK/$SRCNAME/.git"
mkdir -p "$WORK/$SRCNAME/starboard"
cp -r "$HERE/build.sh" "$HERE/deps.env" "$HERE/patches" "$HERE/README.md" "$WORK/$SRCNAME/starboard/"

# The source of these binaries, released beside them.
tar -C "$WORK" --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - "$SRCNAME" \
    | xz -9 -T1 > "$OUT/$SRCNAME-source.tar.xz"

mkdir -p "$WORK/build" "$WORK/bin"
cp -r "$WORK/$SRCNAME/." "$WORK/build/"
ln -s "$TC/llvm-readelf" "$WORK/bin/readelf"
SRC=$WORK/build/src

# ashmem_memfd.c misses <string.h>.
PATH="$WORK/bin:$PATH" \
CPPFLAGS="-I$WORK/deps/usr/include -DARG_MAX=131072 -DVERSION=\\\"$PROOT_VERSION\\\" -ffile-prefix-map=$WORK/=" \
CFLAGS="-Wno-error=implicit-function-declaration" \
LDFLAGS="-L$WORK/deps/usr/lib -landroid-shmem -Wl,-rpath,\\\$\$ORIGIN" \
make -C "$SRC" -j"$(nproc)" \
    CC="$TC/aarch64-linux-android$API-clang" LD="$TC/aarch64-linux-android$API-clang" \
    STRIP="$TC/llvm-strip" OBJCOPY="$TC/llvm-objcopy" OBJDUMP="$TC/llvm-objdump" \
    PROOT_WITH_LIBANDROID_SHMEM=true \
    PROOT_UNBUNDLE_LOADER=/data/data/com.termux/files/usr/libexec/proot \
    proot >"$OUT/build.log" 2>&1 || { tail -30 "$OUT/build.log" >&2; exit 1; }

grep -q '^#define HAVE_SECCOMP_FILTER' "$SRC/build.h" || { echo "built without the seccomp filter" >&2; exit 1; }

# Android only extracts lib*.so from an APK.
install -m755 "$SRC/proot" "$OUT/libproot.so"
install -m755 "$SRC/loader/loader" "$OUT/libproot_loader.so"
"$TC/llvm-strip" --strip-unneeded "$OUT/libproot.so"
"$TC/llvm-strip" --strip-all "$OUT/libproot_loader.so"

(cd "$OUT" && sha256sum libproot.so libproot_loader.so "$SRCNAME-source.tar.xz" > SHA256SUMS)
echo "proot $PROOT_VERSION"
cat "$OUT/SHA256SUMS"
