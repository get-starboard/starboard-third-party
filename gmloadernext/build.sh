#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds gmloadernext.aarch64 from upstream plus patches/. Runs as root inside BUILD_IMAGE
# on x86_64, cross-compiling. Writes the binary's tarball, the source and SHA256SUMS to <out-dir>.
# Usage: gmloadernext/build.sh <out-dir>
set -euo pipefail
[[ $# -eq 1 ]] || { echo "usage: $0 <out-dir>" >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mkdir -p "$1" && cd "$1" && pwd)
. "$HERE/deps.env"

# CI passes the release version from the tag; anything else is marked -dev.
SB_VERSION=${SB_VERSION:-$GMLOADER_VERSION-sb-dev}
[[ "${SB_VERSION%-sb*}" == "$GMLOADER_VERSION" ]] \
    || { echo "version $SB_VERSION doesn't match GMLOADER_VERSION $GMLOADER_VERSION" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
cat > /etc/apt/sources.list <<EOF
deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$APT_SNAPSHOT bullseye main
deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$APT_SNAPSHOT bullseye-updates main
deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/$APT_SNAPSHOT bullseye-security main
EOF
rm -f /etc/apt/sources.list.d/*
dpkg --add-architecture arm64
apt-get -o Acquire::Check-Valid-Until=false update -qq
apt-get install -y -qq --no-install-recommends \
    git ca-certificates python3 python3-clang-11 libclang-11-dev build-essential binutils \
    make pkg-config gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    libsdl2-dev:arm64 libzip-dev:arm64 xz-utils > /dev/null

SRC=/build/gmloadernext-$SB_VERSION
rm -rf /build && mkdir -p "$SRC"
git -C "$SRC" init -q
git -C "$SRC" remote add origin "$GMLOADER_REPO"
git -C "$SRC" fetch -q --depth 1 origin "$GMLOADER_COMMIT"
git -C "$SRC" checkout -q FETCH_HEAD
git -C "$SRC" submodule update -q --init --recursive
git -C "$SRC" apply "$HERE"/patches/*.patch

# The source goes out with every release, as the loader is GPL-2.0-only.
mkdir "$SRC/starboard"
cp -r "$HERE/build.sh" "$HERE/deps.env" "$HERE/patches" "$HERE/README.md" "$SRC/starboard/"
TARBALL=$OUT/gmloadernext-$SB_VERSION-source.tar.xz
tar -C /build --exclude=.git --sort=name --owner=0 --group=0 --numeric-owner \
    -cJf "$TARBALL" "$(basename "$SRC")"

# The defaults come from GitHub's variables and the clock, and name the symbols `strings` finds.
export GITHUB_SHA=$GMLOADER_COMMIT GITHUB_REF_NAME=2024.14-starboard
make -C "$SRC" -f Makefile.gmloader -j"$(nproc)" \
    ARCH=aarch64-linux-gnu \
    BUILD_DATE="${GMLOADER_VERSION}_000000" \
    LLVM_FILE=/usr/lib/llvm-11/lib/libclang-11.so \
    LLVM_INC=/usr/aarch64-linux-gnu/include/c++/10/aarch64-linux-gnu
BIN=$SRC/build/aarch64-linux-gnu/gmloader/gmloadernext.aarch64

# Starboard swaps this over every port's bundled loader: ports with .pvr textures need
# texhack, and games that reference these Steam calls abort while loading without them.
strings -a "$BIN" > /build/strings.txt
for name in disable_texhack steam_lobby_create steam_net_packet_send steam_user_owns_dlc; do
    grep -qx "$name" /build/strings.txt || { echo "the binary has no $name" >&2; exit 1; }
done

# FMOD and video are plugins here. A library linked in would be one the rootfs doesn't have.
EXPECTED="ld-linux-aarch64.so.1 libSDL2-2.0.so.0 libc.so.6 libgcc_s.so.1 libm.so.6 libpthread.so.0 librt.so.1 libstdc++.so.6 libz.so.1"
NEEDED=$(aarch64-linux-gnu-readelf -d "$BIN" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort | xargs)
[[ "$NEEDED" == "$EXPECTED" ]] || { echo "unexpected libraries: $NEEDED" >&2; exit 1; }

STAGE=/build/stage
mkdir -p "$STAGE"
cp "$BIN" "$STAGE/gmloadernext.aarch64"
cp "$SRC/LICENSE.md" "$STAGE/LICENSE.txt"
cat > "$STAGE/SOURCE.txt" <<EOF
gmloadernext, built for Starboard (GPL-2.0-only)

Upstream: $GMLOADER_REPO
Commit:   $GMLOADER_COMMIT, plus Starboard's patches
Source:   gmloadernext-$SB_VERSION-source.tar.xz, on the gmloadernext-$SB_VERSION release of
          https://github.com/get-starboard/starboard-third-party
EOF
tar -C "$STAGE" --sort=name --owner=0 --group=0 --numeric-owner \
    -cJf "$OUT/gmloadernext-$SB_VERSION-aarch64.tar.xz" .
(cd "$OUT" && sha256sum gmloadernext-"$SB_VERSION"-*.tar.xz > SHA256SUMS && cat SHA256SUMS)
