# Coding guidelines for Talkies

Read this file before changing code. Start with [the root README](README.md) for the supported
platforms and repository layout. Long-lived architecture and setup guidance belongs in `docs/`.

## Build, lint, and test

Run commands from the listed directory. Model-backed tests may need locally provisioned model files;
do not let a test silently download weights during an offline inference check.

| Platform | Build | Tests |
|---|---|---|
| macOS | `cd mac && swift build` (release: `swift build -c release`) | `cd mac && swift test` |
| Windows | `cd windows/Talkies.Windows && uv run dotnet build` | `cd windows/Talkies.Windows && uv run dotnet test ../Talkies.Windows.Tests` |
| Linux | `cd linux && ./run.sh build` | `cd linux && ./run.sh test` |
| Android | `cd mobile/android && ./gradlew assembleDebug assembleRelease` | `cd mobile/android && ./gradlew testDebugUnitTest testReleaseUnitTest` |

Toolchain versions, model provisioning, offline acceptance, and packaging details live in the
[platform guides](docs/README.md#platform-build-guides) and
[quality and distribution guide](docs/engineering/quality-and-distribution.md).
Use `uv` for Python tooling and the documented .NET commands; do not wrap SwiftPM, Gradle, or Bun
commands unless their platform guide explicitly says to.

The public website source is on the [`website` branch](https://github.com/4cecoder/talkies/tree/website),
not under this branch's application tree. Follow [its guide](docs/platforms/website.md) and run its
Bun scripts from a checkout of that branch. The deprecated Flutter prototype is archived under
`archive/flutter-prototype/`; it is not a supported build target.

## Code style

### Swift

- Use `@MainActor` for UI state and follow the Swift 6 concurrency model.
- Keep Foundation-only contracts separate from AppKit, AVFoundation, Accessibility, and inference
  frameworks as described in [module boundaries by volatility](docs/architecture/module-volatility.md).
- Handle errors at the boundary that can explain or recover from them.

### C# / WPF

- Follow MVVM and the existing service interfaces.
- Keep nullable reference types enabled; use `StringComparison.OrdinalIgnoreCase` for explicit
  case-insensitive comparisons.
- Dispose native, audio, and stream resources deterministically.
- Keep user-facing errors actionable and avoid swallowing exceptions silently.

### Zig

- Track Zig master as pinned by CI. Do not assume bindings or standard-library APIs from an older
  compiler remain compatible.
- Keep OS and C-library boundaries in the existing modules and generated bindings in the build
  integration; do not hand-edit generated output.
- Use explicit allocator ownership and `defer` for cleanup.

### Kotlin / Android

- Android's supported implementation is native Kotlin in `mobile/android/`.
- Keep UI work on the main dispatcher and file, model-integrity, and inference work off it.
- Preserve the offline boundary: network access is only for an explicit, verified model download.
- Wipe ephemeral PCM buffers after use and invalidate asynchronous work when its input view or
  editor is no longer active.

### TypeScript / website

- This repository's default branch contains no web application. The static website is built from
  the separate `website` branch and deployed through GitHub Pages.
- Follow that branch's ESLint, TypeScript, and accessibility patterns. Keep browser code compatible
  with static export; do not introduce a server-only runtime or hosted service.

## General principles

- Follow existing patterns and module boundaries. Read
  [`docs/architecture/module-volatility.md`](docs/architecture/module-volatility.md) before adding
  a library or moving code between layers.
- Add focused tests for new behavior and update platform or architecture docs when behavior or
  setup changes.
- Keep model weights, secrets, recordings, and transcript content out of source control, logs, and
  issue attachments.
- Preserve third-party license and attribution files. Talkies source is MIT; bundled libraries and
  downloaded models may use different terms.
- Keep recording, recognition, cleanup, and insertion local. Do not add a hosted inference fallback.
