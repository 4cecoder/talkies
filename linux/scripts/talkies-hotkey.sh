#!/usr/bin/env bash
# Forward a compositor key binding to the Talkies daemon.
#
#   talkies-hotkey.sh down    key pressed  (Hyprland: bind)
#   talkies-hotkey.sh up      key released (Hyprland: bindr)
#   talkies-hotkey.sh toggle  single-shot toggle (no release event available)
#
# With down/up the daemon behaves like the macOS app: hold longer than
# push_to_talk_threshold for push-to-talk, tap to start/stop.
set -euo pipefail

case "${1:-}" in
    down) type=hotkey_down ;;
    up) type=hotkey_up ;;
    toggle) type=toggle_recording ;;
    *) echo "usage: $0 down|up|toggle" >&2; exit 2 ;;
esac

port="${TALKIES_WS_PORT:-6789}"
if ! command -v websocat >/dev/null 2>&1; then
    notify-send "Talkies" "websocat not found (needed for compositor hotkeys)" -u critical || true
    exit 1
fi
printf '{"type":"%s"}\n' "$type" | websocat -n1 "ws://127.0.0.1:${port}" >/dev/null
