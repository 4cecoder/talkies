---
title: Linux client
type: platform
status: active
tags: [linux, zig, gtk4, daemon, wayland, x11]
sources: [talkies-di1, talkies-qm0, talkies-ukt, talkies-urc, talkies-hzo, talkies-zgf, talkies-bbk, talkies-tkv, talkies-e2g, talkies-dvl, talkies-7a2, talkies-5dq, talkies-bw6, talkies-pfg, talkies-bph, talkies-cka, talkies-ecn, talkies-j8m, talkies-15m, talkies-b5e, talkies-ll6, talkies-13d, talkies-pq9, talkies-buh, talkies-fna, talkies-mf9, talkies-0o6, talkies-v1u, talkies-xzx]
updated: 2026-10-12
---

# Linux client

Code: `linux/`. A Zig 0.16 daemon that records audio, transcribes it with
whisper.cpp, and pastes the text. GTK4 windows are written in C and called from
Zig. Linux is the platform where new features land first ([[yap-mode]]) and,
as of 2026-10, the focus of the [[epic-linux-macos-parity]] push.

## Built

### Core pipeline (2025-12-17)
- Zig project skeleton and `build.zig` with modules main, audio, whisper,
  clipboard, input, config, utils (`talkies-di1`).
- whisper.cpp C FFI: `loadModel()`, `transcribe()`, `getSegments()`,
  `downloadModel()` (`talkies-qm0`). See [[transcription]].
- PulseAudio recording to WAV with level metering (`talkies-ukt`). See [[audio-capture]].
- TOML config at `~/.config/talkies/config.toml` with load/save/validation and
  defaults; fields model, language, threads, auto_paste, export_format (`talkies-urc`).
- Clipboard + text insertion with Wayland/X11 detection, mirroring the macOS
  clipboard-then-paste pattern (`talkies-hzo`). See [[hotkeys-and-input]].
- CLI commands: `quick`, `record`, `models`, `config`, `audio`, `help` (`talkies-zgf`).
- README / ARCHITECTURE / BUILD docs (`talkies-bbk`, now under `linux/docs/`).

### Daemon and UI (2025-12-19)
- Wayland daemon uses the internal Zig `AudioRecorder` instead of an `arecord`
  script; recording start dropped from 47 ms to 18.5 ms (`talkies-tkv`).
- Start/stop sound effects via `aplay` (`talkies-e2g`).
- [[yap-mode]] (`talkies-bw6`) and [[daemon-status-gui]] (`talkies-pfg`).
- Tokyo Night dark theme applied to all GTK4 windows via a CSS provider (`talkies-dvl`).
- GTK NULL-widget assertions fixed by passing NUL-terminated strings (`dupeZ()`) (`talkies-7a2`).
- `show_status_gui` config option (default true) (`talkies-5dq`).

## Blocked and re-planned

On 2025-12-18 the native settings window, tray icon and recording overlay
(`talkies-bph`, `talkies-ecn`, `talkies-cka`) were closed as blocked because
zig-gobject does not build on Zig 0.16. The interim workaround was an AGS
shell menu. The project then chose raw GTK C interop instead; see
[[zig-016-gtk-c-interop]].

## In progress (2026-10)

The [[epic-linux-macos-parity]] (`talkies-b5e`) brings the daemon UX in line
with the macOS DictationView flow:

- Floating dictation HUD in GTK4 C showing pipeline stages and a waveform (`talkies-ll6`).
- LLM enhance pipeline with Ollama + LM Studio and the five macOS presets
  (`talkies-pq9`), plus matching TOML keys (`talkies-buh`). See [[llm-enhancement]].
- Auto push-to-talk vs toggle hotkey with a 150 ms threshold on X11 and Wayland
  (`talkies-fna`) and clipboard restore after paste (`talkies-mf9`). See [[hotkeys-and-input]].
- Settings window + tray on raw GTK C / D-Bus (`talkies-13d`).

## Backlog

- Native PipeWire capture (`talkies-j8m`, P3) and wake word (`talkies-15m`, P2): [[audio-capture]].
- YAP auto-save and export (`talkies-0o6`, `talkies-xzx`): [[yap-mode]].
- Log interception for the status GUI (`talkies-v1u`): [[daemon-status-gui]].
