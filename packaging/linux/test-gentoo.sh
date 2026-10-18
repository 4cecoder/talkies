#!/usr/bin/env bash
# Emerge both Gentoo packages from the rendered recipes and check they run.
# Runs as root in a gentoo/stage3 container with ::gentoo synced:
#
#   test-gentoo.sh <dist dir> <release label> [bin|source|both]
#
# The ebuilds fetch release assets that only exist once a tag is published,
# so the distfiles are pre-seeded from <dist dir>. Leaves the overlay
# (talkies-gentoo-overlay.tar.gz) and the Zig toolchain the source ebuild
# needs (zig-x86_64-linux.tar.xz) in <dist dir>/gentoo-release for release.yml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$(cd "${1:?dist dir}" && pwd)"
LABEL="${2:?release label}"
WHICH="${3:-both}"
DISTDIR="$(portageq distdir)"
OVERLAY=/var/db/repos/talkies
OUT="${DIST}/gentoo-release"

app_version="$(basename "$(ls "${DIST}"/gentoo/talkies-bin-*.ebuild)" .ebuild)"
app_version="${app_version##*-}"
zig_pv="$(sed -n 's/^ZIG_PV="\(.*\)"$/\1/p' "${DIST}/gentoo/talkies-${app_version}.ebuild")"

mkdir -p "${DISTDIR}" "${OUT}"
cp "${DIST}/Talkies-Linux-${LABEL}.tar.gz" "${DISTDIR}/talkies-bin-${app_version}.tar.gz"
cp "${DIST}/talkies-${app_version}-src.tar.gz" "${DISTDIR}/"
if [[ ! -f "${DISTDIR}/talkies-zig-${zig_pv}.tar.xz" ]]; then
    curl -fsSL --retry 3 -o "${DISTDIR}/talkies-zig-${zig_pv}.tar.xz" \
        "https://ziglang.org/builds/zig-x86_64-linux-${zig_pv}.tar.xz"
fi
cp "${DISTDIR}/talkies-zig-${zig_pv}.tar.xz" "${OUT}/zig-x86_64-linux.tar.xz"

rm -rf "${OVERLAY}"
bash "${SCRIPT_DIR}/gentoo/make-overlay.sh" "${DIST}/gentoo" "${DISTDIR}" "${OVERLAY}"
tar --owner=0 --group=0 -czf "${OUT}/talkies-gentoo-overlay.tar.gz" -C "${OVERLAY}" .

mkdir -p /etc/portage/repos.conf /etc/portage/package.accept_keywords
printf '[talkies]\nlocation = %s\n' "${OVERLAY}" > /etc/portage/repos.conf/talkies.conf
printf 'app-accessibility/talkies ~amd64\napp-accessibility/talkies-bin ~amd64\n' \
    > /etc/portage/package.accept_keywords/talkies

# Containers cannot create the namespaces of Portage's ipc/network/pid
# sandboxes; the filesystem sandbox (what catches stray writes) stays on.
export FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox getbinpkg"
export CLEAN_DELAY=0
export EMERGE_DEFAULT_OPTS="--color=n --quiet-build=y --getbinpkg --usepkg --autounmask-continue"

# Without the official binhost, emerge quietly compiles every dependency
# (LLVM included) and runs past the job's time limit. Fail fast instead.
binhost="$(sed -n 's/^[[:space:]]*sync-uri[[:space:]]*=[[:space:]]*//p' /etc/portage/binrepos.conf/*.conf | head -n1)"
if [[ -z "${binhost}" ]] || ! curl -fsS --retry 5 --retry-delay 30 --retry-all-errors \
    -o /dev/null "${binhost%/}/Packages"; then
    echo "The Gentoo binhost (${binhost:-not configured}) is unreachable; rerun this job later." >&2
    exit 1
fi

check() { # <package>
    talkies --version
    test "$(talkies --version)" = "talkies ${app_version}"
    HOME="$(mktemp -d)" talkies doctor 2>&1 | sed "s/^/   /"
    # Portage owns the files: the updater only gives instructions. No network.
    TALKIES_NO_UPDATE_CHECK=1 talkies update --check 2>&1 | tee /dev/stderr | grep -F ', Gentoo overlay' >/dev/null
    test -f /usr/share/applications/app.talkies.Talkies.desktop
    test -f /usr/share/icons/hicolor/256x256/apps/talkies.png
    find /lib/udev/rules.d /usr/lib/udev/rules.d -name 70-talkies-uinput.rules 2>/dev/null | grep -q .
    emerge --unmerge "$1"
    if [[ -e /usr/bin/talkies ]]; then
        echo "talkies still installed after unmerging $1" >&2
        exit 1
    fi
}

if [[ "${WHICH}" == bin || "${WHICH}" == both ]]; then
    emerge --oneshot app-accessibility/talkies-bin
    check app-accessibility/talkies-bin
fi
if [[ "${WHICH}" == source || "${WHICH}" == both ]]; then
    emerge --oneshot app-accessibility/talkies
    check app-accessibility/talkies
fi
echo "Gentoo ${WHICH} install OK (${app_version})"
