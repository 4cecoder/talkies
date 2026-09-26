# Feature gap analysis

## Scope

This comparison follows Talkies' local-inference requirement in [Product vision](vision.md): after optional first-run model downloads, recognition, cleanup, and insertion must work without external network access. Competitor features are evidence about workflow expectations, not a mandate to add remote inference. Evidence below was checked on **2026-09-25** against official product documentation, changelogs, and the VoiceInk repository. Product capabilities change; recheck these sources before using this as a release comparison.

| Reference product | First-party evidence (checked 2026-09-25) | What is relevant to Talkies |
|---|---|---|
| Superwhisper | [On-device model catalog](https://superwhisper.com/models) states local models need no internet once available; [product page](https://superwhisper.com/) describes custom modes, app activation, shortcuts, file transcription, and meeting capture; [changelog](https://superwhisper.com/changelog) records S1-mini on-device cleanup, local-model management, clipboard preservation, and local Whisper availability. | Local ASR plus optional local cleanup is directly comparable. Its hosted models, hosted meeting processing, and hosted language-model choices are outside Talkies' offline scope. |
| Wispr Flow | Its [security overview](https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq) explicitly says dictated audio is processed in the cloud. Its [Context Awareness guide](https://docs.wisprflow.ai/articles/4678293671-Context-Awareness) describes app-aware style/formatting and local history controls; [remote-desktop guide](https://docs.wisprflow.ai/articles/7336156466-use-flow-with-remote-desktops-citrix-rdp-vdi) documents transcript-history recovery and clipboard workflows. | Use interaction design, app-context behavior, and insertion recovery as workflow references only. Cloud transcription/context transmission is incompatible with Talkies' invariant and is not a gap to close. |
| VoiceInk | The [official repository README](https://github.com/Beingpax/VoiceInk) describes local models, configurable keyboard/mouse shortcuts, app/URL-triggered modes, dictionary/replacements, and assistant workflows. The [v2.20 release](https://github.com/Beingpax/VoiceInk/releases/tag/v2.20), dated 2026-09-19, adds dictionary import/export, auto-learning, Quick History, and mouse shortcuts; its notes also list hosted enhancement models. | Local ASR and customizable workflows are relevant. Assistant and hosted enhancement paths are excluded; verify local mode/model selection for any feature before treating it as an offline parity target. |

## Talkies today

The macOS app has a menu-bar entry with distinct ready, loading, recording, transcribing, cleanup, insertion, success, and attention glyphs; a floating dictation window that can collapse to a waveform sliver; selectable Left or Right Option activation with press/hold detection; AVFoundation recording; WhisperKit transcription with local vocabulary hints; and direct Accessibility insertion into a verified focused text control. Automatic insertion does not touch the clipboard; Copy is an explicit user action. S1-mini cleanup runs in-process through llama.cpp, preferring Metal on Apple Silicon and falling back to CPU; weights remain in persistent storage outside the app bundle. The macOS transcript-history panel shows the active transcript segments; it is not a persistent, searchable history or a file-import workflow. Windows stores vocabulary locally and passes normalized terms to Whisper.net as decoder prompt hints; it has transcript export preferences and recent-export tracking, but not a transcript-history browser or file-import flow in the main UI. Linux has editable Recognition Hints persisted in TOML and passed as whisper.cpp's local initial prompt, an in-process CPU llama.cpp runtime, verified local model downloads, raw-ASR fallback, and a WAV-to-TXT/VTT/SRT export command. The three desktop platforms share local-vocabulary, S1-mini prompt, and TXT/VTT/SRT export fixtures. Their CI chains cached ASR→S1-mini cleanup→a mocked or in-memory insertion boundary and fails closed instead of downloading models during the offline pass. A full app run with OS-level external-network blocking remains open across platforms. GitHub Pages is the sole website deployment target. Releases provide macOS DMG/ZIP, Windows setup EXE/ZIP, and Linux Debian package/tarball assets with checksums and build metadata. Automatic updates and public signing/notarization remain future work.

## Gaps

| Capability | Talkies now | Target | Priority |
|---|---|---|---|
| Capability | Talkies today | High-priority gap | Priority |
|---|---|---|---|
| Offline end-to-end reliability | Cached local ASR and cleanup reach test insertion boundaries on macOS, Windows, and Linux; model provisioning is separate. | Exercise the packaged app on each OS with external networking blocked from recording through real text insertion, while verifying temporary-audio cleanup and configured history behavior. | P0 |
| Activation and insertion recovery | macOS supports Left/Right Option hold activation and verified Accessibility insertion with explicit-copy fallback. Other desktop front ends use different activation/insertion paths; failures need consistent recovery. | User-configurable shortcut combinations and hold/toggle modes with conflict handling, plus a shared, tested recovery path for focus loss, unsupported controls, permission denial, and failed insertion. | P0 |
| Local modes and app-aware formatting | S1-mini offers tested style/structure/context controls; local Ollama/LM Studio modes have presets/custom prompts on supported clients. There is no shared cross-platform mode profile or verified per-app automatic selection. | Portable, editable local profiles for writing task and cleanup settings; optional app-aware switching must read only the minimum context, stay on-device, and be explicit/disableable. | P1 |
| Local vocabulary and replacements | macOS, Windows, and Linux feed local recognition hints; settings differ and there is no shared import/export/replacement contract across clients. | Shared dictionary schema, import/export, replacement rules, and tests proving terms affect both decoding and cleanup without network access. VoiceInk's v2.20 release makes dictionary import/export and learning a concrete workflow reference. | P1 |
| Model choice and lifecycle | Model acquisition, integrity checks, and external-storage paths exist; model selection, deletion, disk use, language/hardware metadata, and cold-start progress are not consistently surfaced on every platform. | A consistent local catalog with clear download/delete/status controls, model requirements and measured load/cold-start behavior. Do not bundle large weights or add cloud fallback. | P1 |
| Files and history across platforms | Local recording and TXT/VTT/SRT export work. Linux has a WAV-to-transcript CLI; the Windows service can transcribe a supplied file, but there is no comparable native import workflow. The macOS history panel displays active transcript segments only; no client offers persistent, searchable transcript history. | Add a user-facing local file import/transcription flow and searchable history with retention/delete controls and reprocess/export behavior on desktop clients. | P1 |
| Meeting workflow | Linux YAP and platform recording pieces are not a complete, cross-platform meeting workflow. | Consider local session capture and transcript first; defer summaries/action items until local model latency, consent cues, and storage controls are designed. | P2 |
| Distribution confidence | CI builds and smoke-tests release artifacts on all three desktop platforms; releases include checksums and build metadata. | Add first-run clean-machine checks for model provisioning, offline operation, and uninstall/data-retention behavior. Automatic updates and signing/notarization are secondary distribution polish. | P1 |

## S1-mini facts and integration constraints

S1-mini is a text normalizer, not an ASR model. Its model card describes 596M unique parameters, English-only input, recommended transcript chunks up to about 1,000 tokens, and Q4_K_M GGUF at 462 MiB. The reported 94.8% token accuracy is measured on held-out English cases and is not a word-error-rate claim. The license is Apache 2.0 with an added requirement to retain the model name “S1-mini by Superwhisper”; preserve its LICENSE and NOTICE if weights are redistributed. Keep weights in persistent user storage rather than bundling them in the app, so application rebuilds do not recopy the 462 MiB artifact. See the [model card](https://huggingface.co/superwhisper/s1-mini).

The card's trained control line accepts four style values (`casual`, `semi-casual`, `semi-formal`, `formal`), two structures (`prose`, `lists`), and two contexts (`general`, `email`). Talkies exposes these tested values and uses the exact system prompt and Qwen3 prefix with thinking disabled. The recommended Q4_K_M GGUF is pinned to a repository commit, SHA-256 verified, and cached locally. Inference uses llama.cpp with Metal layer offload on Apple Silicon when available, falling back to CPU; after the first model download, cleanup runs offline. Blank output for filler-only speech is valid; preserve raw ASR as a safe fallback. macOS CI downloads the pinned model and runs a golden cleanup test.

## Comparison guardrails

- Do not count Wispr Flow's cloud transcription, cloud cleanup, account sync, or context upload as a feature gap for Talkies. Its own security documentation says dictated audio is processed in the cloud. Reimplement only workflow benefits that can be achieved with local models and on-device context.
- Superwhisper and VoiceInk advertise local inference options, but both also expose hosted model choices. Evaluate each mode by its selected ASR/cleanup backend; never imply every competitor workflow works offline.
- Treat marketing accuracy, speed, and privacy statements as vendor claims unless independently measured. This document compares published capabilities, not quality benchmarks.
- All external product claims above were checked on 2026-09-25. The VoiceInk release link is version-pinned; Wispr Flow docs and Superwhisper product/changelog pages are live and may change.

## Delivery sequence

1. Keep the macOS volatility split stable and retain focused audio/recognizer adapter coverage.
2. Close the P0 packaged-app offline and insertion-recovery gaps on each desktop OS.
3. Add shared editable local modes, vocabulary/replacement behavior, and model-management controls.
4. Bring file transcription and searchable local history to Windows/Linux; exercise provisioning and uninstall behavior on clean machines.
5. Consider local meeting capture and app-aware refinements after the core loop is reliable.

## Done means

- Airplane-mode acceptance succeeds after first-run model setup.
- Raw ASR remains available when cleanup is disabled, unavailable, times out, or returns empty output.
- No cloud inference path or remote-model setting ships.
- Each supported desktop platform has repeatable tests, a packaged installable build, and documented model requirements.
