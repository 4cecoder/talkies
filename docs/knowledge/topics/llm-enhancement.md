---
title: LLM enhancement
type: topic
status: active
tags: [llm, ollama, lm-studio, privacy]
sources: [talkies-kys, talkies-mt8, talkies-ggw, talkies-o1j, talkies-bw6, talkies-rdy, talkies-9c3, talkies-spz, talkies-pq9, talkies-buh, talkies-b5e]
updated: 2026-10-12
---

# LLM enhancement

All clients can post-process transcriptions with a **local** LLM so text never
leaves the machine. Two providers are supported: Ollama and LM Studio.

## By platform

- **[[macos]]**: reference implementation. Ollama (`OllamaPlugin.swift`,
  `talkies-kys`), LM Studio (`talkies-mt8`), enhancement modes (`talkies-ggw`)
  and provider/model discovery (`talkies-o1j`) all done in R2. macOS defines
  the **five enhancement presets** that other platforms copy.
- **[[windows]]**: `Plugins/OllamaEnhancer.cs` and `LmStudioProvider.cs` (no beads).
- **[[linux]]**: Ollama used by [[yap-mode]] (`talkies-bw6`, default model
  `granite`). A plain one-shot enhance pipeline is **in progress**:
  - `talkies-pq9`: Ollama + LM Studio with the 5 macOS presets.
  - `talkies-buh`: TOML config keys mirroring macOS `ollama` / `lm_studio` / `enhancer` settings.

## Lessons learned

- Prompt tone matters: an early prompt over-capitalised output like a public
  announcement; the fix was explicitly asking for natural conversational text
  (`talkies-9c3`).
- Zig 0.16 HTTP streaming: read with `allocRemaining`, not `readAlloc`, or you
  get `EndOfStream` (`talkies-rdy`).
- Surface provider health in the UI, and check it is accurate (`talkies-spz`).

Part of [[epic-linux-macos-parity]].
