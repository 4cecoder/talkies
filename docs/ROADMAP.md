# Roadmap

This project used to track work items in an internal issue-tracker tool (Beads, stored under `.beads/`). As part of preparing Talkies for open-source release, that tracker has been removed in favor of this plain markdown roadmap — no special CLI or tooling required, just a normal file anyone can read, discuss, and edit via a regular pull request. The items below are the open and in-progress items that were carried over from the old tracker; closed/completed items were not migrated.

## In Progress

- **[R3/Windows] Dark Mode Improvements** (type: feature, priority: medium)

## Deprecated

- **[R6/Mobile] Flutter Feature Parity & CI/CD Plan** — the Flutter mobile app is deprecated and no longer actively developed; it's been dropped from CI and release builds. See `mobile/README.md`.

## Open

- **Fix Linux `zig build` under Zig master: `@cImport` was removed** — CI now tracks Zig master intentionally (see `.github/workflows/ci.yml`), which surfaced that this Zig nightly line has removed `@cImport` as a language builtin entirely. It's used in 8 files for C interop (`src/audio.zig`, `src/daemon_status_window.zig`, `src/hotkey.zig`, `src/input.zig`, `src/vad.zig`, `src/whisper.zig`, `src/yap_sessions.zig`, `src/yap_window.zig`) and needs a real migration to whatever replaced it (likely `zig translate-c` wired through `build.zig`, or hand-written bindings), not a mechanical rename — see [#146](https://github.com/4cecoder/talkies/issues/146) for full details and current status. Two smaller, likely-quick companion issues found alongside it: a `graphene-config.h` header-not-found error in the GTK C wrappers (probably needs the CI include-path workaround extended, not a code change), and an "operator has whitespace on one side" parse error in `src/websocket.zig:122` on a `** ` array-repeat expression that looks like a new Zig-master syntax strictness rule. (type: bug, priority: high)
- **Implement daemon status GUI with live logs and error indicators** — Create a GTK window showing daemon state, live log viewer with auto-scroll, error indicators, LLM activity, and a stats dashboard for easier debugging (type: feature, priority: high)
- **Add log interception to route stdout/stderr to status GUI** (type: task, priority: high)
- **Test Windows app performance and stability** — Comprehensive testing needed: long recording sessions (30+ minutes), large transcript handling (500+ segments), memory usage during transcription, GPU transcription stability, hotkey reliability from background, and settings persistence across restarts (type: bug, priority: high)
- **[R3] Windows Polish Milestone** — Umbrella milestone for Windows UI polish work (type: epic, priority: medium)
- **Add keyboard shortcuts to Windows UI** — Add InputBindings for common operations: Ctrl+N (new/clear transcript), Ctrl+S (save VTT), Ctrl+E (export menu), Space (start/stop recording), Escape (stop recording), plus shortcut hints in tooltips and menus (type: feature, priority: medium)
- **Add tooltips to Windows UI controls** — Add ToolTipService tooltips to recording controls, export buttons, settings controls, and GPU/audio quality settings for better UX (type: feature, priority: medium)
- **Add Windows application icon and window icon** — Add a window icon, taskbar icon, and system tray icon matching Talkies branding, in multiple resolutions (16x16, 32x32, 48x48, 256x256) (type: feature, priority: medium)
- **Implement YAP session auto-save and recovery** — Auto-save the active YAP session on daemon shutdown and recover an interrupted session on startup, handling crash scenarios gracefully (type: task, priority: medium)
- **Add session export and history viewer** — Export YAP sessions to markdown/JSON, with a CLI tool to view past sessions, search history, and show revision evolution (type: feature, priority: low)
