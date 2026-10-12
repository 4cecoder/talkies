---
title: Talkies knowledge index
type: overview
status: mixed
tags: [index, navigation]
sources: []
updated: 2026-10-12
---

# Talkies knowledge index

Entry point for the Talkies wiki. Format and conventions: [[README]].
Snapshot of beads taken 2026-10-12: 118 issues, 97 closed, 3 in progress, 18 open.

## Start here

- [[project-overview]]: what Talkies is, timeline, and status at a glance.
- [[open-work]]: everything still open or in progress, ranked.
- [[register]]: every bead, one row each (for ID lookup).

## Platforms

- [[linux]]: Zig 0.16 daemon, whisper.cpp, PulseAudio, GTK4 via C. Most active platform.
- [[macos]]: Swift/SwiftUI, WhisperKit, MLX. Reference UX that other platforms mirror.
- [[windows]]: .NET 8 WPF, Whisper.net, NAudio. Polish milestone open.
- [[mobile]]: Flutter app, UI redesign shipped, transcription still pending.
- [[frontend]]: Next.js SaaS site with Stripe + Convex billing.

## Features and cross-cutting topics

- [[yap-mode]]: conversational LLM refinement of a transcription before paste (Linux).
- [[daemon-status-gui]]: GTK debug/status window for the Linux daemon.
- [[llm-enhancement]]: Ollama / LM Studio text enhancement across platforms.
- [[transcription]]: Whisper engines per platform, GPU acceleration.
- [[audio-capture]]: recording backends, latency work, sound feedback, wake word.
- [[hotkeys-and-input]]: global hotkeys, push-to-talk, clipboard and paste.
- [[billing-and-pricing]]: Stripe tiers, promotion codes, Convex backend.
- [[frontend-quality-and-testing]]: strict TypeScript, Prettier, Bun, Playwright E2E.
- [[release-and-packaging]]: CI/CD, installers, auto-update, dependency PRs.
- [[analytics-and-crash-reporting]]: privacy-first telemetry research.
- [[architecture-diagram]]: the business architecture diagram and its updates.

## Decisions

- [[zig-016-gtk-c-interop]]: drop zig-gobject, drive GTK4 through hand-written C.
- [[frontend-toolchain-policy]]: Bun only, strict TS with no `any`, strict Prettier.
- [[force-push-recovery]]: how the 2025-12-19 force-push divergence was resolved.

## Epics and milestones

- [[epic-r1-cross-platform-parity-spec]]: R1, done.
- [[epic-r2-macos-catch-up]]: R2, done.
- [[epic-r3-windows-polish]]: R3, open.
- [[epic-r6-mobile-flutter]]: R6, in progress.
- [[epic-linux-macos-parity]]: Linux catches up to macOS UX, in progress (2026-10).
