---
title: Daemon status GUI
type: topic
status: mixed
tags: [linux, gtk4, debugging, daemon]
sources: [talkies-pfg, talkies-i2u, talkies-2kh, talkies-kbu, talkies-5dq, talkies-7a2, talkies-spz, talkies-dvl, talkies-v1u]
updated: 2026-10-12
---

# Daemon status GUI

A GTK4 window for the [[linux]] daemon that makes debugging easy: daemon state,
live logs, errors, LLM activity, and stats.

## Built (`talkies-pfg`, closed 2025-12-19)

- Status indicators: state, model, platform, connected clients.
- Live log viewer, colour-coded by level (INFO/WARN/ERROR/DEBUG), auto-scroll with toggle.
- Activity monitor (current recording, last transcription time) and stats
  (sessions, errors, average duration).
- Files: `linux/src/daemon_status_gtk.{h,c}` (C GTK wrapper) and
  `linux/src/daemon_status_window.zig` (Zig wrapper).
- Integrated into the `main.zig` daemon loop with GTK event processing
  (`talkies-2kh`) and wired to WebSocket state via `daemon_state.getState()` (`talkies-kbu`).
- `show_status_gui` config option, default true (`talkies-5dq`).
- Fixes: NULL widget pointers solved with NUL-terminated C strings via
  `dupeZ()` (`talkies-7a2`); Ollama indicator wrongly showing "out of
  commission" (`talkies-spz`). Tokyo Night theme (`talkies-dvl`).
- A GTK4 settings dialog for this window landed in commit `e76454f8` (git
  history, no bead).

## Open

- `talkies-v1u` (P1): intercept stdout/stderr and route it into the log viewer.
- `talkies-i2u` (P1): an earlier, broader request for the same GUI. Nearly all
  of its scope shipped under `talkies-pfg`; it is effectively superseded and
  could be closed once `talkies-v1u` lands.
- Untested: behaviour under various error scenarios (TODO on `talkies-pfg`).

Related: [[yap-mode]], [[zig-016-gtk-c-interop]].
