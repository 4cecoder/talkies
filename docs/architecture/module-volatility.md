# Module boundaries by volatility

Talkies has several native applications, but they solve the same local dictation problem. Keep
code that changes for different reasons in separate libraries or modules. This limits the impact
of a model-runtime upgrade, an operating-system API change, or a visual redesign on the rest of
the product.

## Change-rate layers

| Layer | Typical change rate | Owns | Must not own |
|---|---|---|---|
| Contracts and domain rules | Low | Transcript values, cleanup options, export formats, stable protocols, shared golden fixtures | OS frameworks, UI state, model-runtime types |
| Platform adapters | Medium | Microphone capture, permissions, focused-field insertion, global shortcuts, local files and preferences | Model implementation details or cross-platform product policy |
| Inference libraries | High | ASR and cleanup adapters, model stores, native bindings, runtime selection and lifecycle | Views, application navigation, platform-specific presentation |
| App and presentation | High | Window/menu/keyboard UI, user-visible state, onboarding, and composition of adapters | Direct calls into third-party runtime internals |
| Build, package, and release integration | Medium to high | Native dependency wiring, app packaging, installer assembly, signing and release workflow | Product logic or copies of runtime source |
| Vendored dependencies | External | Pinned upstream source and license notices | Talkies-owned behavior; patch upstream code only when the integration requires it |

The table describes ownership, not a requirement to create a new package for every row. Extract a
library when it creates a useful dependency boundary, supports independent tests, or contains a
runtime that changes separately from the app. Avoid adding module overhead for a single file with
no independent boundary.

## Dependency direction

```text
                   ┌── platform adapters ── OS frameworks
app / presentation ├── inference libraries ─ model runtimes
                   └── contracts and domain rules
                               ▲
          platform adapters and inference implement contracts
```

The app is the composition root and may depend on each layer. Contracts stay free of operating
system and inference dependencies. Platform and inference adapters depend on contracts and expose
small interfaces. UI code consumes those interfaces and user-facing results; it does not import
WhisperKit, whisper.cpp, llama.cpp, or ONNX runtime objects directly.

Shared fixtures define behavior at the boundary: prompt framing, cleanup fallback, vocabulary
normalization, export formatting, and insertion text. Platform tests may use different fakes or OS
APIs, but should assert the same contract where behavior is intended to match.

## Current layout

| Platform | Stable boundary | Faster-changing code | Current status |
|---|---|---|---|
| macOS | `mac/Packages/TalkiesCore` | `mac/Packages/TalkiesInference`; `mac/Sources/TalkiesAudio`; `mac/Sources/TalkiesAccessibility`; SwiftUI app in `mac/Sources/Talkies` | Core and inference are separate Swift packages/products; audio and accessibility are separate targets. See [the macOS package design](macos-volatility-split.md). |
| Windows | Shared JSON fixtures under `tests/fixtures`; typed models in `windows/Talkies.Windows/Models` | WPF UI, services, plugins, and Whisper/llama runtime integration in `windows/Talkies.Windows` | Keep current .NET project boundaries; do not extract a library until it has an independent consumer or test need. |
| Linux | Shared JSON fixtures under `tests/fixtures`; transcript/cleanup contracts in Zig source | GTK/Wayland/X11 integration, native inference and build bindings under `linux/src` | Keep generated bindings and third-party build wiring isolated from app policy. |
| Android | Pure Kotlin contracts in `mobile/android/core` | Compose app and input method in `:app`; model stores, cleanup adapter, JNI and native runtimes in `:inference` | The app is the composition root. `:core` has no Android or model-runtime dependency; `:inference` depends on `:core`; `:app` composes both. |

`mobile/android/third_party/whisper.cpp` and `llama.cpp` are pinned submodules. Treat them as upstream-owned. Keep Talkies JNI adapters, CMake options, and third-party license integration inside `mobile/android/inference`; keep microphone capture, permissions, and input-method lifecycle inside `mobile/android/app`.

## When changing a boundary

1. State which change rates or responsibilities the new boundary separates.
2. Keep public types small and owned by the more stable side of the boundary.
3. Define who owns files, models, threads, and cancellation before moving lifecycle code.
4. Put third-party API calls behind an adapter and test fallback behavior at that boundary.
5. Keep the implementation native to its platform unless a shared contract materially reduces
   drift.
6. Update the platform map and build guide in the same pull request; record intentional
   differences instead of forcing false parity.

For new work, first read the [contributing guide](../../CONTRIBUTING.md), then choose the active
platform implementation from the [repository README](../../README.md#repository-layout).
