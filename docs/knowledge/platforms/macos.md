---
title: macOS client
type: platform
status: done
tags: [macos, swift, swiftui, whisperkit, mlx]
sources: [talkies-clp, talkies-e59, talkies-ggw, talkies-h98, talkies-iqr, talkies-kys, talkies-mt8, talkies-ndz, talkies-o1j, talkies-0wz, talkies-b5e]
updated: 2026-10-12
---

# macOS client

Code: `mac/`. Swift 6 + SwiftUI, macOS 15+, WhisperKit for on-device
transcription and MLX for Metal inference, with a plugin system for TTS,
image generation and sentiment.

macOS is the **reference UX**: the [[epic-linux-macos-parity]] work explicitly
copies its DictationView flow, its five LLM enhancement presets and its
Ollama/LM Studio config keys.

## Built (R2, all closed 2025-12-16)

Tracked by [[epic-r2-macos-catch-up]] (`talkies-clp`), delivered mostly in PR #51.
Several items turned out to already exist and were closed after verification.

| Feature | Bead | Outcome |
|---|---|---|
| Persistent settings | `talkies-e59` | PR #51 |
| Microphone picker UI | `talkies-iqr` | PR #51 |
| LM Studio provider | `talkies-mt8` | PR #51 |
| Ollama provider | `talkies-kys` | Already in `OllamaPlugin.swift` |
| LLM enhancement modes | `talkies-ggw` | Already in Ollama/LM Studio plugins |
| Provider/model discovery | `talkies-o1j` | Already in both plugins |
| Global hotkeys | `talkies-h98` | Already via `NSEvent` monitoring |
| Push-to-talk | `talkies-ndz` | Already, on Right Option key |

See also [[llm-enhancement]] and [[hotkeys-and-input]].

## Packaging

DMG/pkg installer research done and documented (`talkies-0wz`). See
[[release-and-packaging]].

## Open

No open macOS beads.
