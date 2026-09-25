# Feature gap analysis

## Scope

This comparison uses the local-only product promise in [Product vision](vision.md). Superwhisper, Wispr Flow, and VoiceInk are reference points for workflow quality; cloud-only models and services are intentionally excluded. Superwhisper describes on-device transcription, custom modes, vocabulary, file transcription, push-to-talk, and meeting capture. VoiceInk documents local transcription, global shortcuts, app-aware modes, a personal dictionary, and assistant workflows. Sources: [Superwhisper features](https://superwhisper.com/), [Superwhisper on-device models](https://superwhisper.com/models), [VoiceInk project](https://github.com/Beingpax/VoiceInk).

## Talkies today

The macOS app has a menu-bar entry with distinct ready, loading, recording, transcribing, cleanup, insertion, success, and attention glyphs; a floating dictation window that can collapse to a waveform sliver; selectable Left or Right Option activation with press/hold detection; AVFoundation recording; WhisperKit transcription with local personal-vocabulary hints; and direct Accessibility text insertion into a verified focused text control. Automatic insertion does not touch the clipboard; Copy is an explicit user action. S1-mini cleanup runs in-process through llama.cpp, preferring the bundled Metal backend on Apple Silicon and falling back to CPU; model weights remain in the user's persistent model cache outside the app bundle. Windows stores local vocabulary in JSON settings and passes normalized terms to Whisper.net as local decoder prompt hints. Its Whisper model catalog is revision-pinned and SHA-256 verified, and CI runs tiny-model ASR and S1-mini cleanup after provisioning, with model-store HTTP requests denied during inference. Linux has editable Recognition Hints persisted in TOML and passed as whisper.cpp's local initial prompt, an in-process CPU llama.cpp runtime, revision-pinned and SHA-256-verified Whisper and cleanup model downloads, raw-ASR fallback, and model-backed ASR and cleanup CI tests. All three desktop platforms consume shared local-vocabulary, S1-mini prompt, and TXT/VTT/SRT export golden fixtures, keeping term normalization, prompt framing, cleanup options, whitespace normalization, and timestamp edge cases aligned. Linux also has an explicit WAV-to-TXT/VTT/SRT export command using local Whisper segment timestamps. macOS, Windows, and Linux CI now chain cached local ASR→S1-mini cleanup→a mocked or in-memory insertion boundary; each acceptance path fails closed rather than downloading missing models during the offline pass. A full app run with OS-level external-network blocking remains open across platforms. GitHub Pages is the sole website deployment target; it serves a static, GitHub-first community front door with no login, billing, or Talkies analytics. The release workflow builds versioned releases and a serialized rolling `latest` prerelease, with macOS DMG/ZIP, Windows setup EXE/ZIP, and Linux Debian package/tarball assets. Automatic update delivery and public signing/notarization remain future work.

## Gaps

| Capability | Talkies now | Target | Priority |
|---|---|---|---|
| Offline speech recognition | WhisperKit on macOS; different engines elsewhere | Documented local model catalog on all desktop platforms; downloadable and usable offline | P0 |
| Transcript cleanup | Embedded S1-mini GGUF through llama.cpp on macOS/Linux and CPU LLamaSharp on Windows; macOS uses Metal on Apple Silicon with CPU fallback; optional loopback Ollama/LM Studio on macOS/Windows and loopback Ollama YAP on Linux | Complete UX parity for tone/format options, tested model lifecycle and airplane-mode behavior; raw-ASR fallback | P0 |
| Swift implementation | SwiftUI shell, `TalkiesCore`, AVFoundation `TalkiesAudio`, Accessibility-isolated `TalkiesAccessibility`, and `TalkiesInference` adapters for WhisperKit and llama.cpp; verified AX insertion; adaptive menu-bar states; signed local app packaging | Expand end-to-end airplane-mode acceptance; keep framework types behind target APIs and verify reproducible signed app bundles | P0 |
| Global activation | Selectable Left or Right Option and a press/hold threshold | Configurable modifier combinations, hold/toggle, cancel, silence stop, conflict checks | P0 |
| Insertion | macOS inserts through Accessibility only into a verified focused text control; unsupported fields use explicit Copy/manual-paste fallback and automatic insertion never changes the clipboard | Permission onboarding, broader app-specific insertion support, undo/recovery | P0 |
| Modes and formatting | Simple plugin enhancement modes | Editable local modes for message, email, prose, lists, code, and translation when the selected ASR supports it | P1 |
| Vocabulary and replacements | macOS/Windows/Linux local terms bias Whisper decoding; settings are platform-specific and terms are not consistently applied to cleanup | Shared local terms, pronunciations, replacements, import/export, use in ASR and cleanup prompts | P1 |
| Model management | WhisperKit downloads to its persistent Hugging Face cache under Documents and initializes on the first recording request while audio capture continues; S1-mini is pinned, SHA-256 checked, stored in Application Support, and initialized lazily for cleanup. Both model stores are outside the small app bundle. | Model catalog, size/license/language/device requirements, download pause/resume, delete, and measured cold-start/core model-load timing | P1 |
| File transcription | Export exists; no clear app-level import workflow | Drag/drop/import common audio/video, batch queue, timestamps, local exports | P1 |
| History | Current screen tracks one transcript | Optional local searchable history, retention controls, edit/reprocess/export/delete | P1 |
| Meeting capture | No complete meeting flow | Explicit session recording, transcript, notes/action items using local models only | P2 |
| Cross-platform parity | Separate implementations, uneven UX and tests | Shared acceptance checklist and local model behavior across macOS, Windows, Linux | P1 |
| Distribution | GitHub Releases with versioned and rolling assets: macOS DMG/ZIP, Windows setup/ZIP, Linux `.deb`/tarball, checksums, and build metadata | Clean-machine first-run model verification, end-to-end offline acceptance, optional signing/notarization; automatic updates remain future work | P1 |
| Documentation | Scattered READMEs and docs | `docs/index.md` hub, task-oriented tutorials, reference pages, architecture, platform guides | P1 |

## S1-mini facts and integration constraints

S1-mini is a text normalizer, not an ASR model. Its model card describes 596M unique parameters, English-only input, recommended transcript chunks up to about 1,000 tokens, and Q4_K_M GGUF at 462 MiB. The reported 94.8% token accuracy is measured on held-out English cases and is not a word-error-rate claim. The license is Apache 2.0 with an added requirement to retain the model name “S1-mini by Superwhisper”; preserve its LICENSE and NOTICE if weights are redistributed. Keep weights in persistent user storage rather than bundling them in the app, so application rebuilds do not recopy the 462 MiB artifact. See the [model card](https://huggingface.co/superwhisper/s1-mini).

The card's trained control line accepts four style values (`casual`, `semi-casual`, `semi-formal`, `formal`), two structures (`prose`, `lists`), and two contexts (`general`, `email`). Talkies exposes these tested values and uses the exact system prompt and Qwen3 prefix with thinking disabled. The recommended Q4_K_M GGUF is pinned to a repository commit, SHA-256 verified, and cached locally. Inference uses llama.cpp with Metal layer offload on Apple Silicon when available, falling back to CPU; after the first model download, cleanup runs offline. Blank output for filler-only speech is valid; preserve raw ASR as a safe fallback. macOS CI downloads the pinned model and runs a golden cleanup test.

## Delivery sequence

1. Keep the macOS volatility split stable by adding focused `TalkiesAudio` and recognizer adapter tests; the package targets and adapters now exist.
2. Keep verified S1-mini cleanup and local ASR vocabulary on macOS, Windows, and Linux; add shared airplane-mode acceptance coverage, shared dictionary behavior, and Linux vocabulary cleanup coverage.
3. Bring configurable shortcuts, insertion recovery, modes, vocabulary, and explicit airplane-mode acceptance to the core dictation loop.
4. Extend the current CI matrix with shared cleanup fixtures, model manifest checks, and end-to-end airplane-mode acceptance; verify the published download page and signed release options.
5. Add file transcription, history, meeting workflow, and app-specific refinements after the core loop is reliable.

## Done means

- Airplane-mode acceptance succeeds after first-run model setup.
- Raw ASR remains available when cleanup is disabled, unavailable, times out, or returns empty output.
- No cloud inference path or remote-model setting ships.
- Each supported desktop platform has repeatable tests, a packaged installable build, and documented model requirements.
