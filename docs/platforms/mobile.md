---
title: Mobile client (Flutter)
type: platform
status: active
tags: [mobile, flutter, android, ios]
sources: [talkies-3sf, talkies-e5y, talkies-cdd, talkies-7k1, talkies-5w6]
updated: 2026-10-12
---

# Mobile client (Flutter)

Code: `mobile/`. Tracked by [[epic-r6-mobile-flutter]] (`talkies-3sf`, in progress).

## Built

- SuperWhisper-inspired UI redesign: glassmorphic design, live waveform
  visualisation, and a mobile CI/CD pipeline (PR #79, noted on `talkies-3sf`).

## The `record` package saga (2025-12-17)

The audio plugin needed four beads to settle, worth knowing before touching it:

1. `talkies-e5y`: audio service fixed for the `record` v4.4.0 API
   (`AudioRecorder` to `Record`, `RecordConfig` parameters).
2. `talkies-cdd`: v4.4.0 failed Android builds with "Namespace not specified";
   upgraded to v5.2.0 (commit `d07d416`).
3. `talkies-7k1`: `AudioRecorderService` updated to the v5.2.0 API with a
   `RecordConfig` wrapper (branch `feature/mobile-ui-redesign`).
4. `talkies-5w6`: final upgrade to v6.1.2 for the Android namespace fix, with
   an API parameter correction.

Current expectation: `record` 6.1.2.

## Open

Whisper integration, local on-device transcription, and platform-specific
features (remaining scope on `talkies-3sf`). See [[transcription]].
