# Quality and distribution

## Why

The CI builds and tests the actual macOS Swift package, runs native Windows and Zig/Linux build-and-test jobs, and checks the frontend on pull requests. macOS CI also downloads the pinned S1-mini GGUF and verifies CPU inference against cleanup assertions. Versioned releases package desktop archives and SHA-256 checksums; native installers and an update path remain planned.

Metanoia provides two useful patterns: a dedicated regression workflow that runs tests on changes, and a rolling `latest` release alongside versioned releases. Talkies should adopt those patterns without allowing an untested rolling build to replace a good release.

## Pull request checks

Required CI should be deterministic, test the actual app/package, and fail on missing tests rather than silently skipping them.

| Surface | Pull-request gate |
|---|---|
| macOS Swift | Swift 6.3+, resolve package, build app/package, run model-free Swift tests, package and inspect the `.app` zip, then download the pinned S1-mini model and run `TALKIES_RUN_MODEL_TESTS=1 swift test --filter S1MiniCleanerIntegrationTests` to verify real CPU inference. |
| Windows | Restore and build WPF app; run all .NET tests; package smoke test |
| Linux | Pin or deliberately track a Zig toolchain only after source compiles on it; build and run unit tests; run headless integration tests under Xvfb where needed |
| Frontend/docs | Bun install from lockfile, TypeScript, ESLint, static export; docs link/structure check |
| Cross-platform contract | Shared cleanup golden fixtures and model manifest schema validation on macOS, Windows, and Linux |

Use changed-path filtering only when it still creates stable required check names. Keep platform workflows separate if needed, but have an aggregate gate fail if a changed platform's tests are skipped. Cache package managers by lockfile hash. Publish logs and test reports on failure.

## Release tracks

1. **PR builds:** CI artifacts for review only; never update `latest`.
2. **Versioned release:** a `vX.Y.Z` tag runs macOS, Windows, and Linux tests, builds desktop archives, generates SHA-256 checksums and release notes, and attaches all artifacts to a GitHub Release. The current workflow publishes the release immediately; draft verification and native installers remain future work.
3. **Rolling latest:** only after a green merge to `master`, publish a prerelease `latest` channel from that exact SHA. Serialize this workflow so concurrent commits cannot move the tag backward.

## Installer targets

- **macOS:** `.app` in a `.dmg` or zip, Apple Silicon first; sign/notarize when credentials exist. Include model downloads as optional first-run assets, not in the app binary.
- **Windows:** portable zip and an installer; sign when a certificate is available. Include runtime dependencies or document them.
- **Linux:** portable archive plus AppImage or `.deb`; bundle non-system runtime libraries and document the baseline distro.
- **Website:** static download page deployed from green `master`; its build must work without private billing or Convex secrets.

Every release should contain version, commit SHA, platform/architecture, signing status, model licenses, and checksums. A failed platform build must prevent partial releases from being presented as complete.

## Current merge blockers for cleanup PR #145

- Verified on 2026-09-24 at head `0a1bd10120c2e12fceac52324caa89261b9d308a`: Linux Zig-master, Windows build and tests, macOS build and tests, the pinned S1-mini CPU cleanup check, frontend typecheck/lint/static export, and Claude review all pass.
- GitHub reports `REVIEW_REQUIRED`; the repository ruleset still requires an approving review. Auto-merge is enabled and will merge after required checks and approval are satisfied.
- The `Vercel` status is red from an account-level integration, but the active ruleset does not require it.
- The GitHub Pages API currently returns 404, so deployment is not yet configured. Enable Pages with Actions as the source after merge, then verify the published site.

The only current PR merge gate is the required approving review. Page publication remains a post-merge distribution task.
