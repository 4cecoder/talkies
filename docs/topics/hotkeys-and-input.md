---
title: Hotkeys, push-to-talk and paste
type: topic
status: active
tags: [hotkeys, push-to-talk, clipboard, x11, wayland]
sources: [talkies-h98, talkies-ndz, talkies-hzo, talkies-fna, talkies-mf9, talkies-1mn, talkies-tkv, talkies-8l1]
updated: 2026-10-12
---

# Hotkeys, push-to-talk and paste

The core loop is: hotkey, record, transcribe, put text at the cursor.

## macOS (reference)
- Global hotkeys via `NSEvent` monitoring (`talkies-h98`).
- Push-to-talk on the Right Option key (`talkies-ndz`).

## Linux
- **Done**: clipboard module with Wayland/X11 detection and get/copy for
  save/restore; `insertTextAtCursor` uses clipboard + simulated paste, like
  macOS, with timing delays (`talkies-hzo`, commit `03c0817`). On Wayland the
  hotkey triggers a toggle script that sends WebSocket commands to the daemon
  (`talkies-tkv`).
- **In progress** ([[epic-linux-macos-parity]]):
  - `talkies-fna`: one hotkey that auto-detects push-to-talk vs toggle using a
    **150 ms** hold threshold, on X11 and Wayland.
  - `talkies-mf9`: restore the user's previous clipboard after pasting.

## Windows
- Open: in-app shortcuts Ctrl+N, Ctrl+S, Ctrl+E, Space, Escape (`talkies-1mn`).
  Background hotkey reliability is part of the stability pass `talkies-8l1`.

Related: [[audio-capture]], [[linux]], [[windows]].
