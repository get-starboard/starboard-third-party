# starboard-prebuilts

A mirror of the third-party native binaries that
[Starboard](https://github.com/get-starboard/starboard) ships inside its APK.

## Why this exists

Starboard runs Linux games on Android via **proot**. proot and its two runtime dependencies are prebuilt for Android
ARM64 by the [Termux](https://termux.com) project and published to Termux's apt
pool. That pool is rolling; it keeps only the current version of each package
and deletes superseded ones. When Termux bumps a version, the old pinned URL
404s and Starboard's build breaks.

This repo holds copies of the `.deb`s Starboard pins as GitHub release assets,
so a build never depends on the Termux pool still having a given version.
Starboard's build fetches them from here and checks each against a pinned SHA-256.

The binaries are unmodified Termux packages. Only binaries are mirrored; the
source stays upstream (linked below).

## Contents

Each release tag (e.g. `proot-5.1.107.85`) holds three assets, proot and its
two runtime dependencies, libtalloc and libandroid-shmem:

| Asset | Version | License | Source | Termux build script |
|---|---|---|---|---|
| `proot_*_aarch64.deb` | 5.1.107.x | GPL-2.0 | https://github.com/termux/proot ¹ | [proot/build.sh](https://github.com/termux/termux-packages/blob/master/packages/proot/build.sh) |
| `libtalloc_*_aarch64.deb` | 2.4.3 | LGPL-3.0 | https://www.samba.org/ftp/talloc/ ² | [libtalloc/build.sh](https://github.com/termux/termux-packages/blob/master/packages/libtalloc/build.sh) |
| `libandroid-shmem_*_aarch64.deb` | 0.7 | BSD-3-Clause | https://github.com/termux/libandroid-shmem ¹ | [libandroid-shmem/build.sh](https://github.com/termux/termux-packages/blob/master/packages/libandroid-shmem/build.sh) |

¹ Use the git tag matching the binary's version. (The proot repo is Termux's
fork of [proot-me/proot](https://github.com/proot-me/proot) with Android patches.)

² Use the `talloc-<version>.tar.gz` matching the binary's version.

## Licensing

The full license text ships with each package's source (linked above). This repo adds no original code beyond this README.
