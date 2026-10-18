# Linux packaging

One x86_64 build, many formats. CI (`.github/workflows/linux-package.yml`) runs this
pipeline on every Linux change and on every release.

| Step | Script | Notes |
| --- | --- | --- |
| Native runtimes | `build-native-deps.sh` | Pinned llama.cpp + whisper.cpp (`deps.env`). whisper links llama's ggml so exactly one `libggml*` ships; `GGML_NATIVE=OFF` (AVX2 baseline); `RUNPATH=$ORIGIN`. |
| Build | `zig build -Doptimize=ReleaseSafe -Dcpu=x86_64_v2 -Dversion=X.Y.Z -Dcommit=<sha> -Dchannel=<label>` | Run inside `ubuntu:22.04`, which sets the floor at glibc 2.35 / GTK 4.6. Newer GTK APIs are resolved at runtime (`linux/src/ui/gtk_compat.h`). The commit and release label let the in-app updater compare rolling `latest` builds against the release's `BUILD-INFO.txt`. |
| Stage | `stage.sh` | FHS tree: `/usr/lib/talkies/{talkies,lib/}`, `/usr/bin/talkies`, desktop entry, AppStream metainfo, hicolor icons, uinput udev rule, licenses. |
| Package | `package.sh` | `.tar.gz` (+ `install-tarball.sh`), and `.deb` / `.rpm` / Arch via nfpm (`nfpm.yaml`, pinned and checksum-verified). Renders `aur/PKGBUILD.in` and the Gentoo ebuilds (`gentoo/talkies-bin.ebuild.in`, prebuilt; `gentoo/talkies.ebuild.in`, from source with the pinned whisper.cpp / llama.cpp / Zig), and writes the source archive. |
| Verify | `test-install.sh` | Installs with each distro's own package manager in clean containers (Ubuntu 22.04/24.04, Debian 12/13, Fedora, AlmaLinux 9, openSUSE Tumbleweed, Arch, tarball on Debian/Fedora), runs `talkies --version`, `talkies doctor` and `talkies update --check` (which must name that install method), removes, and checks user data survives. The AUR recipe is built with `makepkg`. |
| Gentoo | `test-gentoo.sh`, `gentoo/make-overlay.sh` | In `gentoo/stage3`: assembles the overlay with Manifests, then emerges `talkies-bin` and `talkies` (full source build under Portage's sandbox), runs them, and unmerges. The tested overlay and Zig toolchain become release assets. |

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

Tagged releases attach the rendered `PKGBUILD`, both ebuilds, a ready-to-use Gentoo overlay
(`talkies-gentoo-overlay-vX.Y.Z.tar.gz`), the source archive, and the Zig toolchain the source
ebuild builds with. Publishing to the AUR or to GURU needs maintainer accounts.
