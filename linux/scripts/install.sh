#!/usr/bin/env bash
# Install Talkies by volatility tier, replacing only tiers whose bytes changed.
#
#   app     <APP_DIR>/talkies                    every release (Zig app/engine/core)
#   ui      <APP_DIR>/lib/libtalkies-ui.so.1     when windows/tray change
#   native  <APP_DIR>/lib/libtalkies-native.so.1 when the S1-mini runtime changes
#   vendor  <APP_DIR>/lib/lib{whisper,ggml*,llama}.so*  only if missing (--vendor to refresh)
#
# Usage: scripts/install.sh [--prefix /usr/local] [--vendor] [--no-build] [--restart]
set -euo pipefail

prefix=/usr/local
refresh_vendor=0
build=1
restart=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix) prefix="$2"; shift 2 ;;
        --vendor) refresh_vendor=1; shift ;;
        --no-build) build=0; shift ;;
        --restart) restart=1; shift ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

root="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$prefix/lib/talkies"
out="$root/zig-out"

if command -v doas >/dev/null 2>&1; then priv=doas
elif command -v sudo >/dev/null 2>&1; then priv=sudo
else priv=""; fi
as_root() { if [[ -w "$prefix" || -z "$priv" ]]; then "$@"; else "$priv" "$@"; fi; }

if [[ $build -eq 1 ]]; then
    (cd "$root" && zig build -Doptimize=ReleaseSafe)
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$out/bin/talkies" "$stage/talkies"
# Drop build-tree rpaths; installed binaries resolve libraries from lib/.
if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN/lib' "$stage/talkies"
fi

updated=()
install_if_changed() { # tier src dest
    local tier="$1" src="$2" dest="$3"
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        printf '  %-7s unchanged  %s\n' "$tier" "${dest#"$app_dir"/}"
        return
    fi
    as_root install -D -m "${mode:-755}" "$src" "$dest"
    printf '  %-7s UPDATED    %s\n' "$tier" "${dest#"$app_dir"/}"
    updated+=("$tier")
}

echo "Installing into $app_dir"
install_if_changed app "$stage/talkies" "$app_dir/talkies"
for lib in talkies-ui:ui talkies-native:native; do
    name="${lib%%:*}" tier="${lib##*:}"
    real="$(readlink -f "$out/lib/lib$name.so")"
    install_if_changed "$tier" "$real" "$app_dir/lib/lib$name.so.1"
done

# Vendor tier: copy the exact libwhisper/libllama/libggml* the build resolved.
while read -r soname path; do
    dest="$app_dir/lib/$soname"
    if [[ $refresh_vendor -eq 1 || ! -e "$dest" ]]; then
        install_if_changed vendor "$(readlink -f "$path")" "$dest"
    fi
done < <(LD_LIBRARY_PATH="$app_dir/lib:$out/lib" ldd "$out/bin/talkies" "$out/lib/libtalkies-native.so" \
    | awk '$1 ~ /^lib(whisper|llama|ggml)/ && $3 ~ /^\// {print $1, $3}' | sort -u)

# Tray icons belong to the ui tier. Installed twice: beside the app (for
# IconThemePath, which KDE honours) and in the XDG icon path, so hosts that
# only look up named icons in themes (AGS, some waybar setups) find them too.
for icon in "$out"/share/icons/hicolor/scalable/status/*.svg; do
    name="$(basename "$icon")"
    mode=644 install_if_changed ui "$icon" "$app_dir/share/icons/hicolor/scalable/status/$name"
    if [[ ! -f "$prefix/share/icons/hicolor/scalable/status/$name" ]] || ! cmp -s "$icon" "$prefix/share/icons/hicolor/scalable/status/$name"; then
        as_root install -D -m 644 "$icon" "$prefix/share/icons/hicolor/scalable/status/$name"
    fi
done
as_root install -D -m 755 "$root/scripts/talkies-hotkey.sh" "$app_dir/scripts/talkies-hotkey.sh"
wrapper="$(mktemp)"
cat > "$wrapper" <<EOF
#!/bin/sh
# Bundled libwhisper resolves its libggml* siblings via the search path.
export LD_LIBRARY_PATH="$app_dir/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$app_dir/talkies" "\$@"
EOF
as_root install -D -m 755 "$wrapper" "$prefix/bin/talkies"
rm -f "$wrapper"

if [[ ${#updated[@]} -eq 0 ]]; then
    echo "Nothing changed."
    exit 0
fi
echo "Updated tiers: ${updated[*]}"

# Match the process name exactly: `-f` patterns also match any shell whose
# command line merely mentions the daemon path.
if [[ $restart -eq 1 ]] && pgrep -x talkies >/dev/null; then
    pkill -x talkies || true
    sleep 1
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null; then
        hyprctl dispatch exec "$prefix/bin/talkies daemon" >/dev/null
    else
        setsid -f "$prefix/bin/talkies" daemon >/dev/null 2>&1
    fi
    echo "Daemon restarted."
fi
