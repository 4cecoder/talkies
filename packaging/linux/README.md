# Linux packaging

One x86_64 build, many formats. CI (`.github/workflows/linux-package.yml`) runs this
pipeline on every Linux change and on every release.

| Step | Script | Notes |
| --- | --- | --- |
| Native runtimes | `build-native-deps.sh` | Pinned llama.cpp + whisper.cpp (`deps.env`). whisper links llama's ggml so exactly one `libggml*` ships; `GGML_NATIVE=OFF` (AVX2 baseline); `RUNPATH=$ORIGIN`. |
| Build | `zig build -Doptimize=ReleaseSafe -Dcpu=x86_64_v2 -Dversion=X.Y.Z` | Run inside `ubuntu:22.04`, which sets the floor at glibc 2.35 / GTK 4.6. Newer GTK APIs are resolved at runtime (`linux/src/ui/gtk_compat.h`). |
| Stage | `stage.sh` | FHS tree: `/usr/lib/talkies/{talkies,lib/}`, `/usr/bin/talkies`, desktop entry, AppStream metainfo, hicolor icons, uinput udev rule, licenses. |
| Package | `package.sh` | `.tar.gz` (+ `install-tarball.sh`), and `.deb` / `.rpm` / Arch via nfpm (`nfpm.yaml`, pinned and checksum-verified). Renders `aur/PKGBUILD.in` and `gentoo/talkies-bin.ebuild.in`. |
| Verify | `test-install.sh` | Installs with each distro's own package manager in clean containers (Ubuntu 22.04/24.04, Debian 12/13, Fedora, AlmaLinux 9, openSUSE Tumbleweed, Arch, tarball on Debian/Fedora), runs `talkies --version` and `talkies doctor`, removes, and checks user data survives. The AUR recipe is built with `makepkg`. |

Reproduce a release build locally with Docker:

```sh
docker run --rm -it -v "$PWD:/src" -w /src ubuntu:22.04 bash
# inside: install the packages listed in linux-package.yml, Zig master, then
packaging/linux/build-native-deps.sh
(cd linux && zig build -Doptimize=ReleaseSafe -Dcpu=x86_64_v2 -Dversion=0.1.5)
VERSION=v0.1.5 APP_VERSION=0.1.5 OUTPUT_DIR=/src/linux/dist packaging/linux/package.sh
```

Bumping whisper.cpp or llama.cpp: change both commits in `deps.env` together; CI fails if
whisper.cpp no longer builds against that llama.cpp's ggml.

Publishing to the AUR or a Gentoo overlay needs maintainer accounts; tagged releases attach the
rendered `PKGBUILD` and `talkies-bin-X.Y.Z.ebuild` ready to submit.
