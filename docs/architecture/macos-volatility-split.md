# macOS package split by volatility

## Why

The current SwiftPM manifest has one executable target containing the app, WhisperKit integration, plugins, settings, and UI. A change to a fast-moving model runtime therefore rebuilds the whole app and makes the package boundary unclear. Metanoia keeps its stable reader and volatile native-AI companion as separate build products; Talkies can use the same volatility boundary while keeping its user experience in one app.

## Proposed products

| Product/target | Change rate | Owns |
|---|---|---|
| `TalkiesCore` library | Low | Transcript/settings/mode types, privacy rules, formatting, export, model metadata protocols |
| `TalkiesAudio` library | Medium | Microphone capture, device selection, VAD, temporary-file lifecycle |
| `TalkiesInference` library | High | WhisperKit ASR adapter, S1-mini local cleanup adapter, model download/cache/eviction |
| `TalkiesApp` executable | Medium | SwiftUI/AppKit menu bar, hotkeys, onboarding, editor, paste integration |
| `TalkiesModelWorker` executable (optional) | High | Isolated local inference process if runtime churn, memory spikes, or crash containment justify IPC |

The first cut should split SwiftPM targets and keep all runtime work in-process. Make the model worker a separate binary only if profiling demonstrates a measurable stability or memory benefit; the app should not pay IPC complexity in advance.

## Dependency direction

```text
TalkiesApp ──▶ TalkiesCore
    │              ▲
    ├──▶ TalkiesAudio
    └──▶ TalkiesInference ──▶ TalkiesCore
              │
              ├── WhisperKit (ASR)
              └── llama.cpp/MLX backend (S1-mini, selected per platform)
```

`TalkiesCore` must not import AVFoundation, SwiftUI, WhisperKit, MLX, or llama.cpp. Define `SpeechRecognizer` and `TranscriptCleaner` protocols there. Keep third-party inference types inside adapters so updating a model runtime does not leak API churn into the UI or transcript model.

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

The ASR and cleanup stages receive local files/text only. Model downloads go through a model-store service with explicit download state, verified files, version pinning, and offline-ready status. The cleanup protocol returns either cleaned text, a valid empty result, or a typed failure. The pipeline retains raw ASR until cleanup succeeds and follows a user-visible fallback policy.

## Migration order

1. Add `TalkiesCore` as a real target and move only Foundation-only domain code.
2. Move `TranscriptionService` and WhisperKit-specific code to `TalkiesInference`; use an adapter protocol at the app boundary.
3. Add `TalkiesAudio` and keep AVFoundation ownership out of domain types.
4. Move SwiftUI/AppKit code into `TalkiesApp` and add app-bundle packaging.
5. Add S1-mini behind `TranscriptCleaner`; keep model files out of the source bundle unless redistribution terms and artifact size are explicitly handled.

No migration step should silently delete or rewrite the user's uncommitted files.
