# gmloadernext

Starboard's build of [gmloader-next](https://github.com/JohnnyonFlame/gmloader-next),
which runs GameMaker ports. Starboard swaps it over the loader a PortMaster port
bundles. It installs to `/usr/local/lib/starboard/gmloadernext.aarch64` in Starboard's
rootfs.

## The patch

`patches/` adds 26 Steam stubs: lobby, networking and DLC calls. A game that references
a Steam function the loader doesn't stub aborts while loading, with `Unable to find
function`. Mago's is `steam_lobby_create`. The DLC stubs return 0, meaning not owned, as
the loader can't ask Steam. The names come from
[JeodC's fork](https://github.com/JeodC/gmloader-next).

This keeps the commit of PortMaster's November 2025 build, with FMOD and video support
off, as in that build. Before moving to a newer upstream commit, check that it still runs
ports that ship `liboboe.so`, such as Pullywog. JeodC's September 2026 build can't.

The pinned commit isn't on any upstream branch or tag now. If it stops being fetchable,
each release's source tarball still holds it.

## Building

`build.sh` runs as root inside `BUILD_IMAGE` from `deps.env`, on x86_64:

```
. gmloadernext/deps.env
docker run --rm -v "$PWD:/repo:ro" -v "$PWD/out:/out" "$BUILD_IMAGE" bash /repo/gmloadernext/build.sh /out
```

It builds as upstream's CI does for Debian bullseye without video support, and fails if
the binary loses texhack or the stubs, or links a library it shouldn't.

To rebuild from a release's source tarball, including with your own changes, unpack it
and point `GMLOADER_SRC` at the tree. Keep `SB_VERSION` the same as the tarball's, as the
version is part of the build. From the unpacked directory:

```
. starboard/deps.env
docker run --rm -v "$PWD:/src:ro" -v "$PWD/../out:/out" -e GMLOADER_SRC=/src \
    -e SB_VERSION="${PWD##*/gmloadernext-}" "$BUILD_IMAGE" bash /src/starboard/build.sh /out
```

CI does this on every build and fails if the result differs.

## Changing the patch

Commit the change on a checkout of the pinned commit, then export it with
`git format-patch --zero-commit --no-signature`.

## Releases

A `gmloadernext-<version>-sb<n>` tag builds and publishes the binary's tarball, the
patched source and `SHA256SUMS`. `<version>` is `GMLOADER_VERSION` in `deps.env`, the
upstream commit's date in UTC. Starboard's rootfs pins the tarball by SHA-256.

## Licensing

gmloader-next and `patches/` are GPL-2.0-only. `build.sh`, `deps.env` and this README
are GPL-2.0-or-later. `THIRD_PARTY_NOTICES.txt` lists the code compiled into the binary,
and ships beside it.
