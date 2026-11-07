# gmloadernext

Starboard's build of [gmloader-next](https://github.com/JohnnyonFlame/gmloader-next),
which runs GameMaker ports. Starboard swaps it over the loader a PortMaster port
bundles, so one tested build runs them all. It installs to
`/usr/local/lib/starboard/gmloadernext.aarch64` in Starboard's rootfs.

## The patch

`patches/` adds 26 Steam stubs: lobby, networking and DLC calls. A game that references
a Steam function the loader doesn't stub aborts while loading, with `Unable to find
function`. Mago's is `steam_lobby_create`.

The names and the DLC reasoning come from
[JeodC's fork](https://github.com/JeodC/gmloader-next). DLC calls must return 0, as
libyoyo's Android version returns -1 without Steam, which is truthy in GML and could
unlock DLC baked into a game's data.

This keeps the commit PortMaster's most common build uses. Before moving to a newer
upstream commit, check that it still runs ports that ship `liboboe.so`, such as Pullywog.
JeodC's September 2026 build can't.

## Building

`build.sh` runs as root inside `BUILD_IMAGE` from `deps.env`, on x86_64:

```
. gmloadernext/deps.env
docker run --rm -v "$PWD:/repo:ro" -v "$PWD/out:/out" "$BUILD_IMAGE" bash /repo/gmloadernext/build.sh /out
```

It builds as upstream's CI does for Debian bullseye without video support, and fails if
the binary loses texhack or the stubs, or links a library it shouldn't.

## Releases

A `gmloadernext-<version>-sb<n>` tag builds and publishes the binary's tarball, the
patched source and `SHA256SUMS`. `<version>` is `GMLOADER_VERSION` in `deps.env`, the
date of the upstream commit. Starboard's rootfs pins the tarball by SHA-256.

## Licensing

gmloader-next and `patches/` are GPL-2.0-only. `build.sh`, `deps.env` and this README
are GPL-2.0-or-later.
