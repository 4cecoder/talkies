---
title: YAP mode
type: topic
status: mixed
tags: [linux, llm, ollama, yap, gtk4]
sources: [talkies-bw6, talkies-d9g, talkies-jow, talkies-9jn, talkies-9r5, talkies-rdy, talkies-9c3, talkies-0ub, talkies-3bp, talkies-8hz, talkies-uu2, talkies-0sd, talkies-dlg, talkies-dvl, talkies-0o6, talkies-xzx]
updated: 2026-10-12
---

# YAP mode

**What:** instead of pasting a transcription immediately, the user enters a
conversational loop with a local LLM (Ollama, default model `granite`) that
produces progressively refined versions. Aimed at "yappers": verbose speakers
who want a concise, well-crafted message. Linux only for now. Parent bead
`talkies-bw6` (closed 2025-12-19).

## Workflow

1. Record speech as normal.
2. The transcription goes to the LLM for an initial refinement instead of being pasted.
3. The user keeps recording to add context or refinement requests; each new
   transcription is appended to the sandbox (`talkies-0ub`, `talkies-3bp`).
4. The LLM produces new revisions; the user browses them.
5. The user accepts a version, which is copied for pasting.

## How it is built

- **Session manager** integrated into the daemon (`talkies-jow`), with
  accept/refine/cancel controls over WebSocket and terminal prompts (`talkies-d9g`).
- **GTK4 window** with three parts: context, sandbox, and history (`talkies-9jn`).
  Revision history is a read-only, navigable viewer showing "Revision X of Y"
  with prev/next buttons (`talkies-uu2`, `talkies-8hz`). Themed Tokyo Night (`talkies-dvl`).
- **Non-blocking architecture**: YAP state lives outside the main loop, so the
  daemon keeps accepting recordings while the window is open (`talkies-3bp`, commit `cb9ba18`).
- **State guard**: `daemon_ws.zig` ignores `start_recording` while in the
  `yap_refining` state (`talkies-0sd`, commit `a1a2f4c`).
- **Clarification step**: before refining, the LLM may ask multiple-choice
  clarifying questions, answered by voice, to avoid over-interpretation and
  bad acronym guesses (`talkies-dlg`).

## Bugs worth remembering

| Bead | Symptom | Fix |
|---|---|---|
| `talkies-rdy` | `error.EndOfStream` reading Ollama streaming response | Migrated to the Zig 0.16 HTTP API (`allocRemaining` instead of `readAlloc`) |
| `talkies-9r5` | Ollama returned 200 but the GTK window never appeared | No GTK loop was running; window now pumps `g_main_context_iteration()` every 100 ms |
| `talkies-9c3` | Output over-capitalised, like a public announcement | System prompt now asks for a natural conversational tone; button renamed Paste to Copy (commit `abb7d46`) |

The `g_main_context_iteration()` pattern is the same one the [[daemon-status-gui]]
uses; see [[zig-016-gtk-c-interop]] for why GTK is driven manually from Zig.

## Open

- `talkies-0o6` (P2): auto-save the active session on daemon shutdown and
  recover it on startup, including after crashes.
- `talkies-xzx` (P3): export sessions to Markdown/JSON and a CLI history viewer
  with search and revision evolution.

Note: `talkies-bw6` lists three blockers (`talkies-agm`, `talkies-18k`,
`talkies-ih9`) that were later deleted from beads.

Related: [[llm-enhancement]], [[linux]].
