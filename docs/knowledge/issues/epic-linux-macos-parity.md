---
title: "Epic: Linux macOS parity"
type: epic
status: active
tags: [epic, linux, macos, parity, in-progress]
sources: [talkies-b5e, talkies-ll6, talkies-pq9, talkies-buh, talkies-fna, talkies-mf9, talkies-13d, talkies-bph, talkies-cka, talkies-ecn, talkies-hzo]
updated: 2026-10-12
---

# Epic: Linux macOS parity

- **Bead:** `talkies-b5e` (P1, opened 2026-10-12, **in progress**).
- **Goal:** bring the [[linux]] daemon UX in line with the [[macos]]
  DictationView flow: HUD, LLM enhance, hotkey/clipboard, settings + tray.

All children were filed on 2026-10-12 and are being worked now (beads may
still show them as `open`). No `blocks` dependencies are recorded between them yet.

| Bead | Area | Work | Page |
|---|---|---|---|
| `talkies-ll6` | HUD | Floating dictation HUD in GTK4 C with pipeline stages and waveform | [[zig-016-gtk-c-interop]] |
| `talkies-pq9` | LLM | Enhance pipeline: Ollama + LM Studio, the 5 macOS presets | [[llm-enhancement]] |
| `talkies-buh` | Config | Mirror macOS `ollama` / `lm_studio` / `enhancer` keys in TOML | [[llm-enhancement]] |
| `talkies-fna` | Hotkey | Auto push-to-talk vs toggle (150 ms threshold), X11 + Wayland | [[hotkeys-and-input]] |
| `talkies-mf9` | Clipboard | Restore the previous clipboard after paste | [[hotkeys-and-input]] |
| `talkies-13d` | Settings/tray | Settings window + tray on raw GTK C / D-Bus | [[zig-016-gtk-c-interop]] |

## Prior art to reuse

- The HUD supersedes the blocked recording overlay `talkies-cka`; the tray
  supersedes `talkies-ecn`; settings supersede `talkies-bph`.
- GTK C patterns, NUL-terminated strings and the manual GLib loop from
  [[daemon-status-gui]] and [[yap-mode]].
- Existing Linux clipboard save/restore helpers from `talkies-hzo`.
