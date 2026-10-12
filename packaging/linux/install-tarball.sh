#!/usr/bin/env bash
# Install Talkies from the portable tarball.
#
#   ./install.sh              as root: /usr/local   otherwise: ~/.local
#   ./install.sh --prefix DIR
#   ./install.sh --uninstall [--prefix DIR]
#
# Runtime needs from the distro: GTK 4, PulseAudio client libs (PipeWire's
# pipewire-pulse works), SQLite, libX11, D-Bus, and wl-clipboard or xclip.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(id -u)" == 0 ]]; then PREFIX=/usr/local; else PREFIX="${HOME}/.local"; fi
ACTION=install
while (($#)); do
    case "$1" in
        --prefix) PREFIX="${2:?--prefix needs a directory}"; shift 2 ;;
        --uninstall) ACTION=uninstall; shift ;;
        -h | --help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

data="${PREFIX}/share"
udev_rule=/etc/udev/rules.d/70-talkies-uinput.rules
files=(
    "${PREFIX}/bin/talkies"
    "${data}/applications/app.talkies.Talkies.desktop"
    "${data}/metainfo/app.talkies.Talkies.metainfo.xml"
)

refresh() { # best effort: menus refresh on next login without these
    if command -v gtk-update-icon-cache >/dev/null; then
        gtk-update-icon-cache -q -t -f "${data}/icons/hicolor" 2>/dev/null || echo "Note: icon cache not refreshed"
    fi
    if command -v update-desktop-database >/dev/null; then
        update-desktop-database -q "${data}/applications" 2>/dev/null || echo "Note: desktop database not refreshed"
    fi
}

if [[ "${ACTION}" == uninstall ]]; then
    rm -rf "${PREFIX}/lib/talkies" "${data}/talkies" "${data}/doc/talkies"
    rm -f "${files[@]}"
    find "${data}/icons/hicolor" -name 'talkies*' -delete 2>/dev/null || true
    if [[ "$(id -u)" == 0 ]]; then rm -f "${udev_rule}"; fi
    refresh
    echo "Talkies removed from ${PREFIX}. Settings and models in ~/.config/talkies and ~/.local/share/talkies were kept."
    exit 0
fi

mkdir -p "${PREFIX}/bin" "${PREFIX}/lib"
rm -rf "${PREFIX}/lib/talkies"
cp -a "${HERE}/usr/lib/talkies" "${PREFIX}/lib/"
ln -sfn ../lib/talkies/talkies "${PREFIX}/bin/talkies"
mkdir -p "${data}"
cp -a "${HERE}/usr/share/." "${data}/"
# The packaged desktop entry runs `talkies` from PATH; pin the real path so
# menus work even when ${PREFIX}/bin is not on the session PATH.
sed -i "s|^Exec=talkies |Exec=${PREFIX}/bin/talkies |" "${data}/applications/app.talkies.Talkies.desktop"

if [[ "$(id -u)" == 0 ]] && command -v udevadm >/dev/null; then
    install -D -m 0644 "${HERE}/usr/lib/udev/rules.d/70-talkies-uinput.rules" "${udev_rule}"
    # udevd may not be running (containers, chroots); the rule applies at next boot.
    if ! { udevadm control --reload-rules && udevadm trigger --subsystem-match=misc --sysname-match=uinput; } 2>/dev/null; then
        echo "Installed ${udev_rule}; it takes effect after a reboot."
    fi
fi
refresh

"${PREFIX}/bin/talkies" --version
echo "Installed into ${PREFIX}. Start it from your app menu or run: talkies daemon"
echo "Check your system any time with: talkies doctor"
if [[ "$(id -u)" != 0 ]]; then
    echo "Typing into apps needs /dev/uinput access; for that, run once as root: sudo ./install.sh"
fi
case ":${PATH}:" in *":${PREFIX}/bin:"*) ;; *) echo "Note: ${PREFIX}/bin is not on your PATH." ;; esac
