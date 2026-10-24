# mesa

Starboard's build of [Mesa](https://mesa3d.org) for the GPU paths: the virgl
driver, Zink, and Turnip (Mesa's Vulkan driver for Adreno) on the KGSL kernel
driver. It installs to `/opt/sb-mesa` in Starboard's rootfs.

This is a build of Mesa's release tarball, not a fork. Nothing is patched.

## What the tarball holds

Mesa's own output only: `libgallium`, `libEGL_mesa`, `libvulkan_freedreno`
(Turnip), their GLVND and Vulkan ICD files, `licenses/`, `SOURCE.txt` and
`VERSION`. The runtime adds GLVND, the Vulkan loader and the `eglinfo` and
`es2_info` tools from Debian's packages.

## Building

`build.sh` runs as root inside `BUILD_IMAGE` from `deps.env`, on arm64:

```
. mesa/deps.env
docker run --rm -v "$PWD:/repo:ro" -v "$PWD/out:/out" "$BUILD_IMAGE" bash /repo/mesa/build.sh /out
```

It installs the build tools, downloads Mesa's tarball and checks its SHA-256,
builds with the options in `build.sh`, and fails if any library needs a newer
glibc than `GLIBC_LIMIT` (the rootfs's). It writes
`mesa-<version>-aarch64.tar.xz`, `SHA256SUMS` and the build logs to `out`. On
an x86 machine Docker emulates arm64, which is slow. CI uses an arm64 runner.

## Releases

Tags are `mesa-<mesa version>-sb<n>`. The `mesa` workflow builds every change
twice and checks the tarballs match. A tag also publishes the tarball and
`SHA256SUMS` on its release.

## Moving to a new Mesa

Update `MESA_VERSION`, `MESA_URL` and `MESA_SHA256` in `deps.env` (the SHA-256
is in Mesa's release notes), and move `APT_SNAPSHOT` to a recent date if newer
build tools are needed. Push, let CI pass, test on a device, then tag
`mesa-<version>-sb1`.

The build tools come from the Debian snapshot in `APT_SNAPSHOT`, not the live
archive, so rebuilding a tag later gives the same tarball. `BUILD-PACKAGES.txt`
in the tarball lists their versions.

## Licence

Mesa is mostly MIT, with some files under other permissive licences; see
`licenses/` in the tarball and https://docs.mesa3d.org/license.html.
