#!/usr/bin/env bash
# Build every Linux deliverable from one staged tree:
#   Talkies-Linux-<label>.tar.gz       portable, any glibc >= 2.35 distro (install.sh inside)
#   Talkies-Linux-<label>.deb          Debian, Ubuntu, Mint, Pop!_OS
#   Talkies-Linux-<label>.rpm          Fedora, RHEL/Alma/Rocky, openSUSE
#   Talkies-Linux-<label>.pkg.tar.zst  Arch, Manjaro, EndeavourOS
# Also renders the distro recipes in packaging/linux/{aur,gentoo}:
#   PKGBUILD                           AUR talkies-bin (prebuilt tarball)
#   gentoo/talkies-bin-<ver>.ebuild    Gentoo, prebuilt tarball
#   gentoo/talkies-<ver>.ebuild        Gentoo, built from source with the pinned
#                                      whisper.cpp / llama.cpp / Zig (ZIG_VERSION,
#                                      default: `zig version`)
#   talkies-<ver>-src.tar.gz           source archive of HEAD for that ebuild
#
# Requires a finished `zig build` (linux/zig-out) and build-native-deps.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=deps.env
source "${SCRIPT_DIR}/deps.env"

VERSION="${VERSION:?Set VERSION to the release label (v1.2.3, latest, ci-123)}"
APP_VERSION="${APP_VERSION:?Set APP_VERSION to MAJOR.MINOR.PATCH}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT}/linux/dist}"
FORMATS="${FORMATS:-tar deb rpm archlinux}"
if [[ ! "${APP_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "APP_VERSION must be MAJOR.MINOR.PATCH; got ${APP_VERSION}" >&2
    exit 1
fi

built="$("${ROOT}/linux/zig-out/bin/talkies" --version)"
if [[ "${built}" != "talkies ${APP_VERSION}" ]]; then
    echo "linux/zig-out was built as '${built}'; rebuild with -Dversion=${APP_VERSION}" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
STAGE_DIR="${WORK}/root"
DESTDIR="${STAGE_DIR}" "${SCRIPT_DIR}/stage.sh"
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"
base="${OUTPUT_DIR}/Talkies-Linux-${VERSION}"

ensure_nfpm() {
    if command -v nfpm >/dev/null && [[ "$(nfpm --version 2>&1)" == *"${NFPM_VERSION}"* ]]; then
        NFPM=nfpm
        return
    fi
    local archive="${WORK}/nfpm.tar.gz"
    curl -fsSL -o "${archive}" \
        "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz"
    echo "${NFPM_SHA256}  ${archive}" | sha256sum --check --quiet
    tar -xzf "${archive}" -C "${WORK}" nfpm
    NFPM="${WORK}/nfpm"
}

for format in ${FORMATS}; do
    case "${format}" in
        tar)
            dir="${WORK}/talkies-${APP_VERSION}"
            mkdir -p "${dir}"
            cp -a "${STAGE_DIR}/usr" "${dir}/"
            install -m 0755 "${SCRIPT_DIR}/install-tarball.sh" "${dir}/install.sh"
            tar --owner=0 --group=0 -czf "${base}.tar.gz" -C "${WORK}" "talkies-${APP_VERSION}"
            ;;
        deb | rpm | archlinux)
            ensure_nfpm
            ext="${format}"
            [[ "${format}" == archlinux ]] && ext="pkg.tar.zst"
            cp "${SCRIPT_DIR}/nfpm.yaml" "${WORK}/nfpm.yaml"
            cp -r "${SCRIPT_DIR}/scripts" "${WORK}/"
            (cd "${WORK}" && APP_VERSION="${APP_VERSION}" \
                "${NFPM}" package --config nfpm.yaml --packager "${format}" --target "${base}.${ext}")
            ;;
        *)
            echo "Unknown format: ${format}" >&2
            exit 1
            ;;
    esac
done

# Distro recipes that fetch release assets. They pin checksums, so they are
# only installable from tagged (vX.Y.Z) releases; CI tests them by pre-seeding
# the distfiles (see test-gentoo.sh).
if [[ " ${FORMATS} " == *" tar "* ]]; then
    sha="$(sha256sum "${base}.tar.gz" | cut -d' ' -f1)"
    sed "s/@APP_VERSION@/${APP_VERSION}/; s/@SHA256@/${sha}/" "${SCRIPT_DIR}/aur/PKGBUILD.in" \
        > "${OUTPUT_DIR}/PKGBUILD"
fi

# Gentoo: talkies-bin repackages the tarball; talkies builds from the source
# archive with the pinned whisper.cpp / llama.cpp and Zig compiler.
mkdir -p "${OUTPUT_DIR}/gentoo"
cp "${SCRIPT_DIR}/gentoo/talkies-bin.ebuild.in" "${OUTPUT_DIR}/gentoo/talkies-bin-${APP_VERSION}.ebuild"
ZIG_VERSION="${ZIG_VERSION:-$(zig version)}"
sed -e "s/@LLAMA_COMMIT@/${LLAMA_COMMIT}/" -e "s/@WHISPER_COMMIT@/${WHISPER_COMMIT}/" \
    -e "s/@ZIG_VERSION@/${ZIG_VERSION}/" "${SCRIPT_DIR}/gentoo/talkies.ebuild.in" \
    > "${OUTPUT_DIR}/gentoo/talkies-${APP_VERSION}.ebuild"
cp "${SCRIPT_DIR}/gentoo/metadata.xml" "${OUTPUT_DIR}/gentoo/metadata.xml"
# Source archive for the from-source ebuild (and anyone building by hand).
git -C "${ROOT}" -c safe.directory='*' archive --format=tar.gz --prefix="talkies-${APP_VERSION}/" \
    -o "${OUTPUT_DIR}/talkies-${APP_VERSION}-src.tar.gz" HEAD

ls -l "${OUTPUT_DIR}"
