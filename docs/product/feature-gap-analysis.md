# Feature gap analysis

## Scope

This comparison uses the local-only product promise in [Product vision](vision.md). Superwhisper, Wispr Flow, and VoiceInk are reference points for workflow quality; cloud-only models and services are intentionally excluded. Superwhisper describes on-device transcription, custom modes, vocabulary, file transcription, push-to-talk, and meeting capture. VoiceInk documents local transcription, global shortcuts, app-aware modes, a personal dictionary, and assistant workflows. Sources: [Superwhisper features](https://superwhisper.com/), [Superwhisper on-device models](https://superwhisper.com/models), [VoiceInk project](https://github.com/Beingpax/VoiceInk).

## Talkies today

The macOS app has a menu-bar entry, a floating dictation window, Right Option activation with press/hold detection, AVFoundation recording, WhisperKit transcription, cursor insertion, opt-in in-process S1-mini cleanup through llama.cpp on CPU, loopback-only Ollama/LM Studio adapters, basic settings, and TXT/VTT/SRT export. Windows and Linux have independent apps. The repository has platform unit/integration tests and a tag-based release workflow, but the coverage and artifact quality are uneven.

## Gaps

| Capability | Talkies now | Target | Priority |
|---|---|---|---|
| Offline speech recognition | WhisperKit on macOS; different engines elsewhere | Documented local model catalog on all desktop platforms; downloadable and usable offline | P0 |
| Transcript cleanup | Optional embedded S1-mini GGUF through llama.cpp on macOS; optional loopback Ollama/LM Studio; raw-ASR fallback | Built-in local cleanup across desktop platforms, tested controls and model lifecycle | P0 |
| Swift implementation | SwiftUI shell, WhisperKit, stable `TalkiesCore` and volatile `TalkiesInference`; Swift tools 6.3 | Complete split of audio, inference, and app targets with runtime integration tests | P0 |
| Global activation | Right Option and a threshold | User-configurable shortcuts, hold/toggle, cancel, silence stop, conflict checks | P0 |
| Insertion | Accessibility-based text insertion | Pasteboard restore, permissions onboarding, app-specific insertion fallback, undo/recovery | P0 |
| Modes and formatting | Simple plugin enhancement modes | Editable local modes for message, email, prose, lists, code, and translation when the selected ASR supports it | P1 |
| Vocabulary and replacements | No shared dictionary workflow | Local terms, pronunciations, replacements, import/export, use in ASR and cleanup prompts | P1 |
| Model management | WhisperKit initialization/download is mostly automatic | Model catalog, size/license/language/device requirements, progress, pause/resume, delete, checksums | P1 |
| File transcription | Export exists; no clear app-level import workflow | Drag/drop/import common audio/video, batch queue, timestamps, local exports | P1 |
| History | Current screen tracks one transcript | Optional local searchable history, retention controls, edit/reprocess/export/delete | P1 |
| Meeting capture | No complete meeting flow | Explicit session recording, transcript, notes/action items using local models only | P2 |
| Cross-platform parity | Separate implementations, uneven UX and tests | Shared acceptance checklist and local model behavior across macOS, Windows, Linux | P1 |
| Distribution | Basic archives on version tags | Rolling latest + versioned release, native install formats, checksums, update path, signing | P1 |
| Documentation | Scattered READMEs and docs | `docs/index.md` hub, task-oriented tutorials, reference pages, architecture, platform guides | P1 |

## S1-mini facts and integration constraints

S1-mini is a text normalizer, not an ASR model. Its model card describes 596M unique parameters, English-only input, recommended transcript chunks up to about 1,000 tokens, and Q4_K_M GGUF at 462 MiB. The reported 94.8% token accuracy is measured on held-out English cases and is not a word-error-rate claim. The license is Apache 2.0 with an added requirement to retain the model name “S1-mini by Superwhisper”; preserve its LICENSE and NOTICE if weights are redistributed. See the [model card](https://huggingface.co/superwhisper/s1-mini).

The card's trained control line accepts four style values (`casual`, `semi-casual`, `semi-formal`, `formal`), two structures (`prose`, `lists`), and two contexts (`general`, `email`). Talkies exposes these tested values and uses the exact system prompt and Qwen3 prefix with thinking disabled. The recommended Q4_K_M GGUF is pinned to a repository commit, SHA-256 verified, and cached locally. Inference uses llama.cpp with GPU layer offload disabled; after the first model download, cleanup runs offline. Blank output for filler-only speech is valid; preserve raw ASR as a safe fallback. macOS CI downloads the pinned model and runs a golden cleanup test.

## Delivery sequence

1. Finish the macOS volatility split by extracting audio and ASR from the app target.
2. Add model download progress and local model management, then bring the verified cleanup pipeline to Windows and Linux.
3. Bring shortcuts, insertion, modes, vocabulary, and offline guarantees to the core dictation loop.
4. Establish one CI matrix that runs each platform's actual tests and the website checks. Release only artifacts built from green commits.
5. Add file transcription, history, meeting workflow, and app-specific refinements after the core loop is reliable.

## Done means

- Airplane-mode acceptance succeeds after first-run model setup.
- Raw ASR remains available when cleanup is disabled, unavailable, times out, or returns empty output.
- No cloud inference path or remote-model setting ships.
- Each supported desktop platform has repeatable tests, a packaged installable build, and documented model requirements.
