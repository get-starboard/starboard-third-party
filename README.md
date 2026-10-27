# starboard-third-party

Third-party native code that [Starboard](https://github.com/get-starboard/starboard)
ships, either built here from upstream source or mirrored unchanged. Starboard's
build downloads each piece from this repo's releases and checks it against a
pinned SHA-256.

| Directory | What | Built or mirrored | Release tags |
|---|---|---|---|
| [`proot/`](proot/) | proot and its loader, with Starboard's patches | Built here | `proot-<version>-sb<n>` |
| [`mesa/`](mesa/) | Mesa for every video path: virgl, Zink, llvmpipe and Turnip | Built here | `mesa-<version>-sb<n>` |
| none | Termux's libtalloc and libandroid-shmem `.deb`s, which proot needs | Mirrored | `proot-5.1.107.85` |

Tags carry the upstream version, then `-sb<n>`, which counts Starboard's builds
of that version. A tag on a directory's workflow builds it and publishes the
binaries, `SHA256SUMS` and the source on that tag's release. proot's builds it
twice and checks the two builds match first.

## The mirrored packages

Termux's apt pool is rolling: it keeps only the current version of each package
and deletes the others, so a pinned pool URL eventually 404s. The `proot-5.1.107.85`
release keeps copies of the packages Starboard pins:

| Asset | Version | Licence | Source |
|---|---|---|---|
| `libtalloc_2.4.3_aarch64.deb` | 2.4.3 | LGPL-3.0-or-later | https://www.samba.org/ftp/talloc/ (`talloc-2.4.3.tar.gz`), built per [Termux's build.sh](https://github.com/termux/termux-packages/blob/master/packages/libtalloc/build.sh) |
| `libandroid-shmem_0.7_aarch64.deb` | 0.7 | BSD-3-Clause | https://github.com/termux/libandroid-shmem (the tag for 0.7), built per [Termux's build.sh](https://github.com/termux/termux-packages/blob/master/packages/libandroid-shmem/build.sh) |
| `proot_5.1.107.85_aarch64.deb` | 5.1.107.85 | GPL-2.0-or-later | https://github.com/termux/proot (tag `v5.1.107.85`). No longer used: Starboard builds proot from `proot/`. |

## Licensing

Each component keeps its own licence, given above and in its directory's
README. This repo's own files (the build scripts, patches, workflows and
READMEs) are GPL-2.0-or-later: see `LICENSE`. The patches modify proot, which is
GPL-2.0-or-later, and the build scripts ship inside proot's source tarball.
