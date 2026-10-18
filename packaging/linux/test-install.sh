#!/usr/bin/env bash
# Install, exercise, and remove a Talkies package inside a clean distro
# container, using that distro's own package manager so dependency
# metadata is proven, not assumed.
#
#   test-install.sh <dist-dir> <label> [tar]
#
# Picks .deb/.rpm/.pkg.tar.zst by the package manager it finds; with `tar`
# it tests the portable tarball's installer instead (deps via the distro).
set -euo pipefail

DIST="$(cd "${1:?dist dir}" && pwd)" # absolute: apt treats "dir/x.deb" as a release name
LABEL="${2:?release label}"
MODE="${3:-native}"
base="${DIST}/Talkies-Linux-${LABEL}"
# shellcheck source=/dev/null
. /etc/os-release
echo "== ${PRETTY_NAME} (${MODE})"
# User data must survive package removal.
mkdir -p "${HOME}/.config/talkies"
echo keep > "${HOME}/.config/talkies/preserve-check"

install_runtime_deps() { # for the tarball: what a user would install by hand
    if command -v apt-get >/dev/null; then
        apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libgtk-4-1 libpulse0 libsqlite3-0 libgomp1 >/dev/null
    elif command -v dnf >/dev/null; then dnf install -y -q gtk4 pulseaudio-libs sqlite-libs libgomp >/dev/null
    elif command -v zypper >/dev/null; then zypper -n -q install libgtk-4-1 libpulse0 libsqlite3-0 libgomp1 >/dev/null
    elif command -v pacman >/dev/null; then pacman -Sy --noconfirm --needed gtk4 libpulse sqlite >/dev/null
    else echo "no supported package manager" >&2; exit 1; fi
}

if [[ "${MODE}" == tar ]]; then
    install_runtime_deps
    work="$(mktemp -d)"
    tar -xzf "${base}.tar.gz" -C "${work}"
    installer="$(echo "${work}"/talkies-*/install.sh)"
    "${installer}"
    bin=/usr/local/bin/talkies
    method="tarball (install.sh)"
elif command -v apt-get >/dev/null; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${base}.deb" >/dev/null
    bin=/usr/bin/talkies
    method="Debian package (apt)"
elif command -v dnf >/dev/null; then
    dnf install -y -q "${base}.rpm" >/dev/null
    bin=/usr/bin/talkies
    method="RPM package (dnf)"
elif command -v zypper >/dev/null; then
    zypper -n -q --no-gpg-checks install --allow-unsigned-rpm "${base}.rpm" >/dev/null
    bin=/usr/bin/talkies
    method="RPM package (zypper)"
elif command -v pacman >/dev/null; then
    pacman -Sy --noconfirm >/dev/null
    pacman -U --noconfirm "${base}.pkg.tar.zst" >/dev/null
    bin=/usr/bin/talkies
    method="Arch package (pacman)"
else
    echo "no supported package manager" >&2
    exit 1
fi

real="$(readlink -f "${bin}")"
if ldd "${real}" | grep -F 'not found'; then
    echo "unresolved libraries after install" >&2
    exit 1
fi
"${bin}" --version
# Headless: every check must run and report, never crash.
"${bin}" doctor 2>&1 | sed 's/^/   /'
# The updater must know who owns this install. Release builds follow a
# channel, so turn the network check off; the install method prints first.
update_check="$(TALKIES_NO_UPDATE_CHECK=1 "${bin}" update --check 2>&1)"
echo "${update_check}" | sed 's/^/   /'
if [[ "${update_check}" != *", ${method}"* ]]; then
    echo "talkies update --check did not detect the ${method} install" >&2
    exit 1
fi
test -f "$(dirname "${real}")/../../share/applications/app.talkies.Talkies.desktop"
test -f "$(dirname "${real}")/../../share/icons/hicolor/256x256/apps/talkies.png"

if [[ "${MODE}" == tar ]]; then
    "${installer}" --uninstall
elif command -v apt-get >/dev/null; then apt-get remove -y -qq talkies >/dev/null
elif command -v dnf >/dev/null; then dnf remove -y -q talkies >/dev/null
elif command -v zypper >/dev/null; then zypper -n -q remove talkies >/dev/null
elif command -v pacman >/dev/null; then pacman -R --noconfirm talkies >/dev/null
fi
if [[ -e "${bin}" || -e "${real}" ]]; then
    echo "talkies still present after removal" >&2
    exit 1
fi
grep -qx keep "${HOME}/.config/talkies/preserve-check"
echo "== PASS ${PRETTY_NAME} (${MODE})"
