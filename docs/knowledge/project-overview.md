---
title: Project overview
type: overview
status: mixed
tags: [overview, timeline, roadmap]
sources: [talkies-0ye, talkies-clp, talkies-a4p, talkies-3sf, talkies-b5e, talkies-bw6, talkies-pfg, talkies-di1, talkies-bph, talkies-oxp, talkies-l8y, talkies-r8w, talkies-05d, talkies-a18, talkies-d5p, talkies-inh, talkies-kf0]
updated: 2026-10-12
---

# Project overview

Talkies is a privacy-first voice transcription product: speak, get text pasted
where your cursor is, with all transcription done on-device. Optional local LLMs
(Ollama, LM Studio) clean up or rewrite the text. There are native clients for
[[macos]], [[windows]] and [[linux]], a Flutter [[mobile]] app, and a Next.js
SaaS [[frontend]] that sells subscriptions ([[billing-and-pricing]]).

## Release model

Work was organised into numbered milestones (bead epics):

| Milestone | Bead | Status | Page |
|---|---|---|---|
| R1 Cross-platform parity spec | `talkies-0ye` | done | [[epic-r1-cross-platform-parity-spec]] |
| R2 macOS catch-up | `talkies-clp` | done | [[epic-r2-macos-catch-up]] |
| R3 Windows polish | `talkies-a4p` | open | [[epic-r3-windows-polish]] |
| R6 Mobile Flutter parity + CI/CD | `talkies-3sf` | in progress | [[epic-r6-mobile-flutter]] |
| Linux macOS parity | `talkies-b5e` | in progress | [[epic-linux-macos-parity]] |

R4/R5 have no beads (none recorded in the tracker).

## Timeline (from bead dates)

- **2025-12-16**: Planning burst. R1 spec written; R2 macOS features confirmed
  or shipped (PR #51) with Stripe frontend (PR #52); Windows GPU and audio
  quality settings; packaging, auto-update and analytics research
  (`talkies-l8y`, `talkies-05d`, `talkies-kf0`, `talkies-inh`).
- **2025-12-17**: Frontend hardening (strict TS, Prettier, Bun, Playwright E2E),
  Stripe + Convex billing (PRs #85-#87), mobile `record` package fixes, and the
  Linux Zig rewrite begins (`talkies-di1`, whisper FFI, PulseAudio, config, CLI).
- **2025-12-18**: Attempt to adopt zig-gobject for GTK4 fails on Zig 0.16;
  GTK features disabled. See [[zig-016-gtk-c-interop]].
- **2025-12-19**: Linux feature day: [[yap-mode]] end to end,
  [[daemon-status-gui]], Wayland audio fix, Tokyo Night theme, sound feedback.
  Also a force-push incident was recovered ([[force-push-recovery]]) and the
  [[architecture-diagram]] was refreshed.
- **2025-12-27**: Linux backlog ideas: PipeWire native capture, wake word.
- **2026-10-12**: Linux macOS-parity epic opened (`talkies-b5e`), following the
  repo commit that removed the legacy Tauri code and committed to Zig 0.16 +
  C interop for GTK.

## Status at a glance

- Done: R1, R2, YAP mode, daemon status GUI core, Linux core pipeline,
  frontend quality gates, billing infrastructure.
- In progress: [[epic-linux-macos-parity]], [[epic-r6-mobile-flutter]],
  Stripe/Convex frontend wiring (`talkies-d5p`), Windows dark mode (`talkies-a18`).
- Open: [[epic-r3-windows-polish]], YAP auto-save/export, log interception.
  Full list in [[open-work]].
