# Quality and distribution

## Why

The CI builds and tests the actual macOS Swift package, runs native Windows and Zig/Linux build-and-test jobs, and checks the frontend on pull requests. macOS CI downloads the pinned S1-mini GGUF and verifies CPU cleanup inference, then exercises WhisperKit transcription from a provisioned tiny-model folder with framework downloads disabled. Versioned releases package desktop archives and SHA-256 checksums; native installers and an update path remain planned.

Metanoia provides two useful patterns: a dedicated regression workflow that runs tests on changes, and a rolling `latest` release alongside versioned releases. Talkies should adopt those patterns without allowing an untested rolling build to replace a good release.

## Pull request checks

Required CI should be deterministic, test the actual app/package, and fail on missing tests rather than silently skipping them.

| Surface | Pull-request gate |
|---|---|
| macOS Swift | Swift 6.3+, resolve package, build app/package, run model-free Swift tests, package and inspect the `.app` zip and DMG, then download the pinned S1-mini model and run `TALKIES_RUN_MODEL_TESTS=1 swift test --filter S1MiniCleanerIntegrationTests` to verify CPU cleanup inference. Provision the WhisperKit tiny model and run `TALKIES_RUN_WHISPERKIT_MODEL_TESTS=1 swift test --filter WhisperKitRecognizerTests/testTranscribesWithCachedModelWhenDownloadsAreDisabled` to exercise ASR with framework downloads disabled. |
| Windows | Restore and build WPF app; run fast .NET tests; cache and integrity-check pinned Whisper tiny and S1-mini weights, then run CPU ASR and cleanup with model-store HTTP requests rejected during inference |
| Linux | Track Zig master; build CPU-only llama.cpp and whisper.cpp; build the app and run unit tests plus a pinned S1-mini download/inference test on CPU |
| Frontend/docs | Bun install from lockfile, TypeScript, ESLint, static export; docs link/structure check |
| Cross-platform contract | Shared cleanup golden fixtures and model manifest schema validation on macOS, Windows, and Linux |

Use changed-path filtering only when it still creates stable required check names. Keep platform workflows separate if needed, but have an aggregate gate fail if a changed platform's tests are skipped. Cache package managers by lockfile hash. Publish logs and test reports on failure.

## Release tracks

1. **PR builds:** CI artifacts for review only; never update `latest`.
2. **Versioned release:** a `vX.Y.Z` tag runs macOS, Windows, and Linux tests, builds the macOS app ZIP and DMG plus Windows and Linux portable archives, generates SHA-256 checksums and build metadata, and attaches all artifacts to a GitHub Release. The current workflow publishes the release immediately; Windows and Linux native installers remain future work.
3. **Rolling latest:** each push to `master` runs the platform release builds and tests, then force-updates the `latest` prerelease tag to that tested SHA and replaces its assets. The workflow serializes updates per release channel so concurrent commits cannot move `latest` backward.

## Installer targets

- **macOS:** `.app` in a `.dmg` or zip, Apple Silicon first; sign/notarize when credentials exist. Include model downloads as optional first-run assets, not in the app binary.
- **Windows:** portable zip and an installer; sign when a certificate is available. Include runtime dependencies or document them.
- **Linux:** portable archive plus AppImage or `.deb`; bundle non-system runtime libraries and document the baseline distro.
- **Website:** static download page deployed from green `master`; its build is a static export with no account backend or billing secrets.

Every release should contain version, commit SHA, platform/architecture, signing status, model and bundled-library licenses, and checksums. A failed platform build must prevent partial releases from being presented as complete.

GitHub Pages is the sole website deployment target. It serves the static website at
`https://4cecoder.github.io/talkies/` from the dedicated `gh-pages` branch. The deployment workflow
rebuilds only the frontend export from `master` and replaces the published branch contents. Current
pull request checks and review requirements are shown on GitHub rather than copied into this
long-lived guide.
