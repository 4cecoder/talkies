# macOS package split by volatility

## Why

The package graph separates Foundation-only `TalkiesCore`, AVFoundation-based `TalkiesAudio`, Accessibility-based `TalkiesAccessibility`, and volatile `TalkiesInference`, which owns the llama.cpp S1-mini adapter, WhisperKit ASR adapter, and their model lifecycles. `TalkiesCore` and `TalkiesInference` are separate dynamic products embedded beside `llama.framework` in the app bundle. The executable links both dylibs, and the inference dylib links Core and llama. The executable owns the SwiftUI/AppKit shell, status and transcript presentation, settings, and plugins.

## Products and targets

| Product/target | Change rate | Owns |
|---|---|---|
| `TalkiesCore` dynamic library | Low | Transcript/settings/mode types, privacy rules, formatting, export, model metadata protocols |
| `TalkiesAudio` library | Medium | AVFoundation microphone capture, input device selection, level monitoring, temporary recording files |
| `TalkiesAccessibility` library | Medium | Focus capture, verified text-control insertion, permission checks, explicit clipboard copy |
| `TalkiesInference` dynamic library | High | llama.cpp S1-mini cleanup adapter, WhisperKit ASR adapter, and both model lifecycles |
| `Talkies` executable | Medium | SwiftUI/AppKit menu bar, hotkeys, onboarding, editor, and application coordination |
| `TalkiesModelWorker` executable (optional) | High | Isolated local inference process if runtime churn, memory spikes, or crash containment justify IPC |

Keep inference in-process for now. Make the optional model worker a separate binary only if profiling demonstrates a measurable stability or memory benefit.

## Dependency direction

```text
Talkies ──▶ libTalkiesCore.dylib
    ├──▶ TalkiesAudio ───────────────▶ AVFoundation/CoreAudio
    ├──▶ TalkiesAccessibility ───────▶ libTalkiesCore.dylib
    └──▶ libTalkiesInference.dylib ──▶ libTalkiesCore.dylib
                   ├──▶ WhisperKit (ASR)
                   └──▶ llama.framework (S1-mini)
```

`TalkiesCore` must not import AVFoundation, SwiftUI, WhisperKit, or llama.cpp. Define `SpeechRecognizer` and `TranscriptCleaner` protocols there. Keep third-party inference types inside adapters so updating a model runtime does not leak API churn into the UI or transcript model.

## SPM layout

```text
mac/
  Package.swift
  Packages/
    TalkiesCore/Package.swift
    TalkiesInference/Package.swift
  Sources/
    TalkiesAudio/
    TalkiesAccessibility/
    Talkies/
  Tests/
    TalkiesCoreTests/
    TalkiesAudioTests/
    TalkiesAccessibilityTests/
    TalkiesInferenceTests/
```

The manifests use Swift tools 6.3. The app consumes Core and Inference as package products, so a target-only split cannot leave inference objects statically linked into the executable. `package-app.sh` checks executable and dylib dependency edges, embeds both dylibs and `llama.framework`, and signs nested code before the app. The DMG smoke test checks runtime files after install and replacement-upgrade simulation. Keep third-party inference APIs behind runtime adapters. Core and Accessibility tests cover formatting, cleanup prompts, transcript contracts, focused-app validation, permission denial, unsupported controls, and insertion fallbacks. The model-backed cleanup integration test runs after provisioning the pinned weights and denies network requests during inference.

## Offline and cleanup boundary

```text
AVAudioEngine → SpeechRecognizer.transcribe → raw transcript
              → optional TranscriptCleaner.clean → insertion/export
```

The ASR and cleanup stages receive local files/text only. Model downloads go through a model-store service with verified files, version pinning, and offline-ready status. The cleanup protocol returns either cleaned text, a valid empty result, or a typed failure. The pipeline retains raw ASR until cleanup succeeds and follows a user-visible fallback policy.

## Migration order

1. `TalkiesCore` is a real target with Foundation-only transcript and cleanup contracts.
2. `TalkiesAudio` owns microphone recording, device selection, level monitoring, and audio-file lifecycle.
3. Keep WhisperKit types behind `WhisperKitRecognizer`; add focused model-free adapter tests and isolate presentation state from inference.
4. Move SwiftUI/AppKit code into `TalkiesApp` and add app-bundle packaging.
5. Add model progress and explicit download/delete controls. The model-backed CPU golden test now runs in macOS CI. Keep model files out of the source bundle unless redistribution terms and artifact size are explicitly handled.

No migration step should silently delete or rewrite the user's uncommitted files.
