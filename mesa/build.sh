#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds Mesa for /opt/sb-mesa: virgl and Zink, and Turnip on KGSL. Runs as root inside
# BUILD_IMAGE (arm64). Writes the install tarball and SHA256SUMS to <out-dir>.
# Usage: mesa/build.sh <out-dir>
set -euo pipefail
[[ $# -eq 1 ]] || { echo "usage: $0 <out-dir>" >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mkdir -p "$1" && cd "$1" && pwd)
. "$HERE/deps.env"
[[ "$(uname -m)" == aarch64 ]] || { echo "run inside $BUILD_IMAGE on arm64" >&2; exit 1; }

# CI passes the release version from the tag; anything else is marked -dev.
SB_VERSION=${SB_VERSION:-$MESA_VERSION-sb-dev}
[[ "${SB_VERSION%-sb*}" == "$MESA_VERSION" ]] \
    || { echo "version $SB_VERSION doesn't match MESA_VERSION $MESA_VERSION" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
rm -f /etc/apt/sources.list.d/debian.sources
echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$APT_SNAPSHOT trixie main" \
    > /etc/apt/sources.list
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    build-essential meson ninja-build pkg-config python3-mako python3-yaml python3-packaging \
    bison flex glslang-tools libexpat1-dev zlib1g-dev libzstd-dev libdrm-dev libglvnd-dev \
    libelf-dev ca-certificates curl xz-utils binutils llvm-19-dev libpolly-19-dev libffi-dev libxml2-dev libz3-dev > /dev/null

# A fixed source path, and a fixed hash seed for Mesa's Python code generators, keep
# the build reproducible.
export PYTHONHASHSEED=0
SRC=/build/mesa-$MESA_VERSION
PREFIX=/opt/sb-mesa
STAGE=/build/stage
rm -rf /build && mkdir -p /build "$STAGE"
curl -fsSL --retry 3 -o /build/mesa.tar.xz "$MESA_URL"
echo "$MESA_SHA256  /build/mesa.tar.xz" | sha256sum -c --quiet -
tar -C /build -xJf /build/mesa.tar.xz

# softpipe gives SDL's offscreen driver the EGL device it looks for. msm keeps libdrm,
# which Mesa drops for Turnip on KGSL alone, though virgl's DRM winsys needs it. The
# commas are meson's list syntax.
# shellcheck disable=SC2054
MESON_OPTS=(
    "--prefix=$PREFIX" --libdir=lib --buildtype=release -Db_ndebug=true --wrap-mode=nodownload
    -Dgallium-drivers=virgl,zink,softpipe,llvmpipe -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl,msm
    -Dplatforms= -Degl=enabled -Dglx=disabled -Dglvnd=enabled -Dgbm=disabled
    -Dgles1=enabled -Dgles2=enabled -Dllvm=enabled -Dshared-llvm=disabled -Dvalgrind=disabled -Dlibunwind=disabled
    -Dgallium-va=disabled -Dgallium-rusticl=false -Dvideo-codecs= -Dbuild-tests=false
    -Dtools= -Dvulkan-layers=
)
# Logs go to <out-dir>, and a failure prints the end of its log.
step() { local log=$OUT/$1.log; shift; "$@" > "$log" 2>&1 || { tail -40 "$log" >&2; exit 1; }; }
step meson meson setup /build/out "$SRC" "${MESON_OPTS[@]}"
step ninja ninja -C /build/out
DESTDIR=$STAGE step install ninja -C /build/out install
T=$STAGE$PREFIX

# Runtime files only. GLVND and the Vulkan loader come from the rootfs's packages.
rm -rf "$T/include" "$T/lib/pkgconfig"
find "$T/lib" -maxdepth 1 -name '*.so' -type l -delete
strip --strip-unneeded "$T"/lib/*.so*

# No library may need a newer glibc than the rootfs has.
for f in "$T"/lib/*.so*; do
    v=$(objdump -T "$f" | { grep -o 'GLIBC_[0-9.]*' || true; } | sed 's/GLIBC_//' | sort -V | tail -1)
    [[ -z "$v" || "$(printf '%s\n%s\n' "$v" "$GLIBC_LIMIT" | sort -V | tail -1)" == "$GLIBC_LIMIT" ]] \
        || { echo "$f needs GLIBC_$v, above $GLIBC_LIMIT" >&2; exit 1; }
done

mkdir -p "$T/licenses"
cp "$SRC/docs/license.rst" "$T/licenses/mesa-license.rst"
echo "$SB_VERSION" > "$T/VERSION"
# The gallium drivers, for the launcher to tell a build with llvmpipe.
echo "virgl zink softpipe llvmpipe" > "$T/DRIVERS"
{
    echo "Mesa $MESA_VERSION, built for Starboard as $SB_VERSION"
    echo "source: $MESA_URL"
    echo "sha256: $MESA_SHA256"
    echo "image: $BUILD_IMAGE"
    echo "apt snapshot: $APT_SNAPSHOT (packages in BUILD-PACKAGES.txt)"
    echo "compiler: $(cc --version | head -1)"
    echo "meson: $(meson --version)"
    echo "options: ${MESON_OPTS[*]}"
    echo "build script: https://github.com/get-starboard/starboard-third-party/tree/mesa-$SB_VERSION/mesa"
} > "$T/SOURCE.txt"
dpkg-query -W -f='${Package} ${Version}\n' > "$T/BUILD-PACKAGES.txt"

NAME=mesa-$SB_VERSION-aarch64.tar.xz
tar -C "$STAGE" --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --mode='u=rwX,go=rX' \
    -cf - "${PREFIX#/}" | xz -9 -T1 > "$OUT/$NAME"
(cd "$OUT" && sha256sum "$NAME" > SHA256SUMS)
echo "mesa $SB_VERSION"
tar -tJvf "$OUT/$NAME" | awk '{print $3, $6}'
cat "$OUT/SHA256SUMS"
