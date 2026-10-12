---
title: Transcription engines
type: topic
status: mixed
tags: [whisper, transcription, gpu, privacy]
sources: [talkies-qm0, talkies-0t9, talkies-3sf, talkies-tkv]
updated: 2026-10-12
---

# Transcription engines

Privacy-first: every platform transcribes on-device with a Whisper variant.

| Platform | Engine | Notes | Beads |
|---|---|---|---|
| [[macos]] | WhisperKit (+ MLX) | Apple Silicon optimised | none |
| [[windows]] | Whisper.net | GPU via CUDA/DirectML with detection, UI toggle, error handling | `talkies-0t9` |
| [[linux]] | whisper.cpp via Zig C FFI | `loadModel`, `transcribe`, `getSegments`, `downloadModel`, unit tests | `talkies-qm0` |
| [[mobile]] | not yet | Whisper integration and local transcription still open | `talkies-3sf` |

Export formats (SRT, VTT, TXT) are shared across desktop apps.

Latency on Linux is dominated by capture start/stop rather than inference;
see the 350 ms trailing-word grace period in [[audio-capture]] (`talkies-tkv`).
