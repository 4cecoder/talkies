#!/usr/bin/env bash
# Build every Linux deliverable from one staged tree:
#   Talkies-Linux-<label>.tar.gz       portable, any glibc >= 2.35 distro (install.sh inside)
#   Talkies-Linux-<label>.deb          Debian, Ubuntu, Mint, Pop!_OS
#   Talkies-Linux-<label>.rpm          Fedora, RHEL/Alma/Rocky, openSUSE
#   Talkies-Linux-<label>.pkg.tar.zst  Arch, Manjaro, EndeavourOS
# Gentoo and AUR recipes live in packaging/linux/{gentoo,aur}.
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

# Distro recipes that fetch the tarball from the GitHub release. They pin its
# SHA-256, so they are only meaningful for tagged (vX.Y.Z) releases.
if [[ " ${FORMATS} " == *" tar "* ]]; then
    sha="$(sha256sum "${base}.tar.gz" | cut -d' ' -f1)"
    sed "s/@APP_VERSION@/${APP_VERSION}/; s/@SHA256@/${sha}/" "${SCRIPT_DIR}/aur/PKGBUILD.in" \
        > "${OUTPUT_DIR}/PKGBUILD"
    cp "${SCRIPT_DIR}/gentoo/talkies-bin.ebuild.in" "${OUTPUT_DIR}/talkies-bin-${APP_VERSION}.ebuild"
fi

ls -l "${OUTPUT_DIR}"
