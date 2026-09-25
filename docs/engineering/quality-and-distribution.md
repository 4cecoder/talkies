# Quality and distribution

## Why

The CI builds and tests the actual macOS Swift package, runs native Windows and Zig/Linux build-and-test jobs, and checks the frontend on pull requests. macOS CI provisions the pinned S1-mini GGUF and WhisperKit tiny model, then runs an integrated cached-model acceptance test through ASR, S1-mini cleanup, and `TextInserter` with a mocked Accessibility client. Windows CI similarly chains cached Whisper ASR, CPU S1-mini cleanup, and a mocked insertion boundary with both model-store HTTP clients rejecting requests. Linux runs an integrated cached-model ASR→S1-mini cleanup→in-memory insertion acceptance pass; model downloaders fail closed during this pass if a verified model or required license asset is missing. A full app test under an OS-level block on all external networking also remains planned. Release builds validate platform packages and publish SHA-256 checksums. Models are provisioned before the offline acceptance steps.

Metanoia provides two useful patterns: a dedicated regression workflow that runs tests on changes, and a rolling `latest` release alongside versioned releases. Talkies should adopt those patterns without allowing an untested rolling build to replace a good release.

## Pull request checks

Required CI should be deterministic, test the actual app/package, and fail on missing tests rather than silently skipping them.

| Surface | Pull-request gate |
|---|---|
| macOS Swift | Swift 6.3+, resolve package, build app/package, run model-free Swift tests, package and inspect the `.app` zip and DMG, then provision the pinned S1-mini model and run `TALKIES_RUN_MODEL_TESTS=1 swift test --filter S1MiniCleanerIntegrationTests` to verify on-device cleanup. Provision the WhisperKit tiny model and run `TALKIES_RUN_WHISPERKIT_MODEL_TESTS=1 swift test --filter WhisperKitRecognizerTests/testTranscribesWithCachedModelWhenDownloadsAreDisabled` to exercise ASR with framework downloads disabled. |
| Windows | Restore and build WPF app; run fast .NET tests; cache and integrity-check pinned Whisper tiny and S1-mini weights, then run CPU ASR and cleanup with model-store HTTP requests rejected during inference |
| Linux | Track Zig master; build CPU-only llama.cpp and whisper.cpp; build and test the app, then smoke-test the portable archive and Debian package, including install, upgrade, uninstall, and preservation of user data. |
| Frontend/docs | Bun install from lockfile, TypeScript, ESLint, static export; docs link/structure check |
| Cross-platform contract | Shared S1-mini prompt and TXT/VTT/SRT export golden fixtures on macOS, Windows, and Linux; model manifest schema validation |

Use changed-path filtering only when it still creates stable required check names. Keep platform workflows separate if needed, but have an aggregate gate fail if a changed platform's tests are skipped. Cache package managers by lockfile hash. Publish logs and test reports on failure.

## Release tracks

1. **PR builds:** CI artifacts for review only; never update `latest`.
2. **Versioned release:** a `vX.Y.Z` tag runs macOS, Windows, and Linux tests, builds the macOS app ZIP and DMG, Windows setup EXE and portable ZIP, and Linux Debian package and portable tarball, generates SHA-256 checksums and build metadata, and attaches all artifacts to a GitHub Release. The workflow publishes after every platform job succeeds.
3. **Rolling latest:** each push to `master` runs the platform release builds and tests, then force-updates the `latest` prerelease tag to that tested SHA and replaces its assets. The workflow serializes updates per release channel so concurrent commits cannot move `latest` backward.

## Installer targets

- **macOS:** `.app` in a `.dmg` or zip, Apple Silicon first; sign/notarize when credentials exist. Model weights stay in persistent user storage, outside the app bundle.
- **Windows:** self-contained portable ZIP and a per-user NSIS installer; sign when a certificate is available. The installer preserves settings and model files outside its application directory.
- **Linux:** Debian/Ubuntu `.deb` plus portable archive; bundle Whisper/llama runtime libraries and resolve system dependencies through package metadata or platform documentation.
- **Website:** static download page deployed from green `master`; its build is a static export with no account backend or billing secrets.

Every release should contain version, commit SHA, platform/architecture, signing status, model and bundled-library licenses, and checksums. A failed platform build must prevent partial releases from being presented as complete.

GitHub Pages is the sole website deployment target. It serves the static website at
`https://4cecoder.github.io/talkies/` from the dedicated `gh-pages` branch. The deployment workflow
rebuilds only the frontend export from `master` and replaces the published branch contents. Current
pull request checks and review requirements are shown on GitHub rather than copied into this
long-lived guide.
