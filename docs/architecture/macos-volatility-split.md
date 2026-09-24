# macOS package split by volatility

## Why

The SwiftPM manifest separates Foundation-only `TalkiesCore`, AVFoundation-based `TalkiesAudio`, and volatile `TalkiesInference`, which owns the llama.cpp S1-mini adapter and pinned GGUF model lifecycle. The executable owns the SwiftUI/AppKit shell, WhisperKit integration, settings, and plugins. The next extraction is moving the ASR adapter into `TalkiesInference`.

## Proposed products

| Product/target | Change rate | Owns |
|---|---|---|
| `TalkiesCore` library | Low | Transcript/settings/mode types, privacy rules, formatting, export, model metadata protocols |
| `TalkiesAudio` library | Medium | AVFoundation microphone capture, input device selection, level monitoring, temporary recording files |
| `TalkiesInference` library | High | llama.cpp S1-mini cleanup adapter and its pinned GGUF lifecycle; WhisperKit ASR adapter and model lifecycle remain to be moved here |
| `TalkiesApp` executable | Medium | SwiftUI/AppKit menu bar, hotkeys, onboarding, editor, paste integration |
| `TalkiesModelWorker` executable (optional) | High | Isolated local inference process if runtime churn, memory spikes, or crash containment justify IPC |

The first cut should split SwiftPM targets and keep all runtime work in-process. Make the model worker a separate binary only if profiling demonstrates a measurable stability or memory benefit; the app should not pay IPC complexity in advance.

## Dependency direction

```text
TalkiesApp ──▶ TalkiesCore
    │              ▲
    ├──▶ TalkiesAudio ──▶ AVFoundation/CoreAudio
    └──▶ TalkiesInference ──▶ TalkiesCore
              │
              ├── WhisperKit (ASR)
              └── llama.cpp CPU backend (S1-mini)
```

`TalkiesCore` must not import AVFoundation, SwiftUI, WhisperKit, or llama.cpp. Define `SpeechRecognizer` and `TranscriptCleaner` protocols there. Keep third-party inference types inside adapters so updating a model runtime does not leak API churn into the UI or transcript model.

## SPM layout

```text
mac/
  Package.swift
  Sources/
    TalkiesCore/
    TalkiesAudio/
    TalkiesInference/
      ASR/
      Cleanup/
      ModelStore/
    TalkiesApp/
  Tests/
    TalkiesCoreTests/
    TalkiesAudioTests/
    TalkiesInferenceTests/
    TalkiesAppTests/
```

The manifest should use Swift tools 6.3 and explicitly define separate library targets. Keep dependency versions isolated in the model runtime target. Add a small model-free `TalkiesCore` test target so formatters, mode configuration, cleanup prompt construction, and fallback rules run quickly on every macOS CI pass. Inference integration tests use tiny fixtures or a separately gated model-download job; never make the normal test suite download hundreds of megabytes.

## Offline and cleanup boundary

```text
AVAudioEngine → SpeechRecognizer.transcribe → raw transcript
              → optional TranscriptCleaner.clean → insertion/export
```

The ASR and cleanup stages receive local files/text only. Model downloads go through a model-store service with verified files, version pinning, and offline-ready status. The cleanup protocol returns either cleaned text, a valid empty result, or a typed failure. The pipeline retains raw ASR until cleanup succeeds and follows a user-visible fallback policy.

## Migration order

1. `TalkiesCore` is a real target with Foundation-only transcript and cleanup contracts.
2. `TalkiesAudio` owns microphone recording, device selection, level monitoring, and audio-file lifecycle.
3. Move `TranscriptionService` and WhisperKit-specific code to `TalkiesInference`; use a recognizer protocol at the app boundary.
4. Move SwiftUI/AppKit code into `TalkiesApp` and add app-bundle packaging.
5. Add model progress and explicit download/delete controls. The model-backed CPU golden test now runs in macOS CI. Keep model files out of the source bundle unless redistribution terms and artifact size are explicitly handled.

No migration step should silently delete or rewrite the user's uncommitted files.
