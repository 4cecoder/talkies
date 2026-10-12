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
| **Enhancement** | Off, **S1-mini** (on-device), **Ollama**, or **LM Studio**. Ollama and LM Studio use the five macOS presets: Grammar & Clarity, Technical Writing, Concise & Professional, Creative Enhancement, AI Companion. They also support the same tuning parameters, and Ollama accepts a custom system prompt and stop sequences. |
| **Text insertion** | Clipboard plus a paste keystroke through a built-in uinput keyboard. Your previous clipboard is restored afterwards. |
| **Tray icon** | Click to show or hide the window. The menu has Open Talkies, Start/Stop Recording, Settings…, and Quit Talkies. |
| **Settings window** | General, Transcription, Enhancement, Output and Advanced pages. Changes save automatically after 0.5 s. |
| **Voice assistant mode** | Speaks the result through `spd-say` or `espeak-ng`, and can optionally insert it too. |
| **Linux extras** | Silence trimming (WebRTC VAD), YAP refinement window (opt-in), WebSocket API, and TXT/VTT/SRT export from the CLI. |

## Build and run

```bash
cd linux
zig build                 # requires Zig master (0.16+), GTK4, libwhisper, libllama, PulseAudio, dbus
zig build test
./zig-out/bin/talkies daemon
```

Runtime tools:
- `wl-clipboard` or `xclip`, for the clipboard.
- Write access to `/dev/uinput`, for pasting. Add a udev rule or join the `input` group.
- `websocat`, for compositor hotkeys.
- Optional: `speech-dispatcher` or `espeak-ng`, for voice assistant mode.

## Hotkeys

**X11:** Right Alt works out of the box through a global grab.

**Wayland:** global key grabs aren't allowed, so bind the key in your
compositor and forward it with `scripts/talkies-hotkey.sh`. Hyprland example
(see `hyprland-overlay-rules.conf`):

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
