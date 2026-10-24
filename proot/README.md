# proot

Starboard's build of [termux/proot](https://github.com/termux/proot). The APK
carries the binaries as `libproot.so` and `libproot_loader.so`.

## Changes from upstream

`patches/`, applied to the upstream commit pinned in `deps.env`:

- **0001 Trace only the ioctl commands proot acts on.** Upstream's seccomp
  filter traces every ioctl. This one traces `SIOCGIFINDEX`, the termios
  commands and `FICLONE`, which are the ones `src/syscall/enter.c` and
  `src/syscall/exit.c` handle. Other ioctls, such as a GPU driver's submits,
  run without stopping in the tracer.
- **0002 Say this is a modified PRoot.** `--version` and `--help` name
  Starboard and link here.

## Licence

PRoot is GPL-2.0-or-later (see `COPYING` in the source), and so are these
patches. libtalloc (LGPL-3.0-or-later) and libandroid-shmem (BSD-3-Clause) are
Termux's builds, unmodified.

Each release carries `proot-<version>-source.tar.xz`: the upstream tree with
the patches applied, and this directory.

## Building

```
NDK=/path/to/android-ndk-r28c proot/build.sh out
```

Needs `git`, `curl`, `patchelf`, `xz` and the NDK revision in `deps.env`. It
clones upstream at the pinned commit, applies the patches, fetches Termux's
talloc and shmem packages and checks their SHA-256s, then builds with Termux's
package options. It writes `libproot.so`, `libproot_loader.so`, the source
tarball and `SHA256SUMS` to `out`. The same inputs give the same hashes on any
machine.

## Moving to a new upstream tag

1. Update `PROOT_UPSTREAM_TAG` and `PROOT_UPSTREAM_COMMIT` in `deps.env`.
2. Rebase the patches: apply them to the new tree with `git am`, fix any
   conflicts, and export them again with `git format-patch --zero-commit
   --no-signature`.
3. Check `src/syscall/enter.c`, `src/syscall/exit.c` and the extensions for
   ioctl commands proot acts on, and update `traced_ioctls[]` in patch 0001 to
   match.
4. Push, let the workflow pass, test on a device, then tag
   `proot-<version>-sb1`.
