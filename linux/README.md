# Talkies for Linux

Local voice dictation that works like the macOS app: hold or tap a hotkey,
speak, and the cleaned-up text is typed into whatever app has focus.
Transcription runs on-device (whisper.cpp). LLM enhancement only talks to
servers on this machine.

## What you get

| | |
|---|---|
| **Floating dictation window** | 520×140 pill with an animated gradient, a live 60-bar waveform, a status dot, and pipeline stages (Recording → Transcribing → Enhancing → Inserting → Done!). It never takes keyboard focus and hides 1.5 s after finishing. |
| **Hotkey** | Right Alt. Hold it longer than `push_to_talk_threshold` (0.15 s) for push-to-talk, or tap it to start and stop. |
| **Enhancement** | Off by default. Choose **S1-mini** (on-device: download, progress and removal in Settings), **Ollama**, or **LM Studio**. Ollama and LM Studio use the five macOS presets: Grammar & Clarity, Technical Writing, Concise & Professional, Creative Enhancement, AI Companion. They also support the same tuning parameters, and Ollama accepts a custom system prompt and stop sequences. |
| **Text insertion** | Clipboard plus a paste keystroke through a built-in uinput keyboard. Your previous clipboard is restored afterwards. |
| **Tray icon** | The one Talkies control in your bar, like the macOS menu-bar item. Click to show or hide the window. The menu has Open Talkies, Start/Stop Recording, Settings…, and Quit Talkies. Works with any StatusNotifierItem host (AGS, waybar, KDE). |
| **Settings window** | General, Transcription, Enhancement, Output and Advanced pages. Changes save automatically after 0.5 s. |
| **Voice assistant mode** | Speaks the result through `spd-say` or `espeak-ng`, and can optionally insert it too. |
| **Linux extras** | Silence trimming (WebRTC VAD), YAP refinement window (opt-in), WebSocket API, and TXT/VTT/SRT export from the CLI. |

## Build, test and install

```bash
cd linux
zig build                  # requires Zig master (0.16+), GTK4, libwhisper, libllama, PulseAudio, dbus
zig build test             # all layers; or test-core (no system deps), test-engine, test-app
scripts/install.sh --restart   # ReleaseSafe build into /usr/local/lib/talkies, restart the daemon
scripts/install.sh --prefix /usr --libdir lib64 --restart  # Gentoo layout
```

`install.sh` replaces only the tiers whose bytes changed (see below), and
uses doas or sudo when it needs to.

## Layout: split by volatility

The code and the binaries are both grouped by how often they change. Imports
only point down the stack, and the build graph enforces this: `core` imports
nothing, `engine` sees only `core`.

| Tier | Change rate | Source | Ships as |
|---|---|---|---|
| vendor | lowest | whisper.cpp, ggml, llama.cpp | `lib/libwhisper.so.1`, `libggml*.so.0`, `libllama.so.0` |
| native | low | `src/native`: S1-mini runtime (C ABI over llama.cpp) | `lib/libtalkies-native.so.1` |
| phonon | low | Pinned CrispASR runtime for optional Phonon-2 recognition | `lib/crispasr/*` |
| core | low | `src/core`: utils, WAV parsing, hints, export, diagnostics. Pure Zig. | linked into `talkies` |
| engine | low | `src/engine`: PulseAudio, VAD, Whisper, clipboard, uinput, X11 hotkey, WebSocket | linked into `talkies` |
| ui | medium | `src/ui`: GTK4 HUD, settings, status, YAP windows, D-Bus tray | `lib/libtalkies-ui.so.1` |
| app | highest | `src/app`: daemon pipeline, config schema, LLM prompts, hotkey policy, YAP, CLI | `talkies` |

The app binary links neither GTK nor llama.cpp directly: those sit behind
the `ui` and `native` libraries' C ABIs.

Runtime tools:
- `wl-clipboard` or `xclip`, for the clipboard.
- Write access to `/dev/uinput`, for pasting. Add a udev rule or join the `input` group.
- `websocat`, for compositor hotkeys.

Recordings go to a private `$XDG_RUNTIME_DIR/talkies` directory (mode 0700)
and are deleted after transcription.
- Optional: `speech-dispatcher` or `espeak-ng`, for voice assistant mode.

## What runs by default

Only the daemon and a tray icon. The dictation window appears while you
dictate and hides 1.5 s after "Done!". Settings are built the first time you
open them. The status monitor, YAP window, enhancement and sounds are all
off until you enable them.

The daemon is event-driven: it blocks on its hotkey, D-Bus and wake file
descriptors, so it uses no CPU while idle. Audio capture and transcription
run on their own threads, so the window never stalls.

## When something isn't working

Talkies checks your system (audio server, microphone, hotkey access, paste
permission, clipboard tool, tray) at startup, whenever Settings opens, and
whenever recording fails.

- **Settings > General** shows a single "Ready to dictate" line, or the
  problem and its fix, with a collapsed **Details** list of every check.
- **The tray tooltip** shows the same one-line summary.
- **Errors in the dictation window** name the real cause, e.g. "No audio
  server is running" instead of a generic failure.
- **`talkies doctor`** prints the full report in a terminal. Fixes are
  specific to your system (OpenRC/Gentoo, systemd, GNOME, and so on).

## Desktop support

| Desktop | Tray | Dictation window |
|---|---|---|
| KDE Plasma | Native StatusNotifierItem + dbusmenu. The icon recolours with your Plasma colour scheme (`ColorScheme-Text` SVGs); middle-click starts or stops recording. | Floats above other windows without taking focus (XWayland hints, honoured by KWin) |
| Hyprland (AGS, waybar) | Same item; icons are installed into the XDG icon theme so hosts that ignore `IconThemePath` still find them | Window rules applied automatically via `hyprctl` |
| GNOME | Needs the "AppIndicator and KStatusNotifierItem Support" extension (the doctor tells you) | Same as KDE (Mutter honours the hints) |

## Hotkeys

Right Alt everywhere: hold it for push-to-talk, or tap it to toggle.

- **X11:** a global grab.
- **Wayland:** read directly from the keyboard devices when you are in the
  `input` group. Only the Right Alt key code is inspected.

Without `/dev/input` access, bind a key in your compositor and forward it
with `scripts/talkies-hotkey.sh`. Hyprland example (see
`hyprland-overlay-rules.conf`):

```ini
bind  = ,    Alt_R, exec, ~/talkies/linux/scripts/talkies-hotkey.sh down
bindr = ALT, Alt_R, exec, ~/talkies/linux/scripts/talkies-hotkey.sh up
```

With `down`/`up` you get the same hold-or-tap behaviour as macOS. Compositors
without release bindings can use `talkies-hotkey.sh toggle`.

On Hyprland the daemon applies window rules at startup with `hyprctl`, so the
dictation window floats, stays pinned and never steals focus.

## Configuration

`~/.config/talkies/config.toml`. The sections mirror the macOS
`~/.talkies/config.json` keys in snake_case:

```toml
[general]
push_to_talk_threshold = 0.15
show_hud = true

[enhancement]
provider = "ollama"            # none | s1_mini | ollama | lm_studio

[ollama]
selected_model = "llama3.2:3b"
host = "http://localhost:11434"
enhancement_mode = "grammar"   # grammar | technical | concise | creative | companion
temperature = 0.3
top_p = 0.9
top_k = 40
repeat_penalty = 1.1
context_length = 2048
max_tokens = 500

[lm_studio]
endpoint = "http://127.0.0.1:1234"
max_tokens = 4096

[output]
auto_paste = true
paste_keybind = "ctrl+v"       # ctrl+shift+v for terminals
restore_clipboard = true
```

Older configs keep working: `[cleanup] s1_mini_enabled` still maps onto the
enhancer setting.

## WebSocket API (`ws://127.0.0.1:6789`)

Commands you can send:
- `start_recording`
- `stop_recording`
- `toggle_recording`
- `hotkey_down`
- `hotkey_up`
- `get_state`
- `yap_accept`
- `yap_refine`
- `yap_cancel`

Events the daemon sends:
- `state_changed`
- `pipeline_stage`
- `audio_level` (about 20 Hz while recording)
- `transcription_complete`
- `yap_refined`
- `error`

Set `TALKIES_WS_PORT` to run a development build next to an installed daemon.

## Other commands

```
talkies quick | record | models | config | audio | audio-list | audio-set <dev>
talkies transcribe file.wav --format srt --output file.srt
```

More docs: [`docs/`](docs/) (build, dependencies, shipping) and the project
wiki in [`../docs/`](../docs/index.md).
