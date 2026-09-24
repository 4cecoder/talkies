# Quality and distribution

## Why

The current CI selects macOS, Windows, and Linux jobs, but the macOS job writes a temporary package manifest that skips the full app, Linux is currently blocked on Zig master removing `@cImport`, and the frontend has no pull-request build gate. The release workflow packages basic archives; it does not yet provide a complete installer/update path across supported systems.

Metanoia provides two useful patterns: a dedicated regression workflow that runs tests on changes, and a rolling `latest` release alongside versioned releases. Talkies should adopt those patterns without allowing an untested rolling build to replace a good release.

## Pull request checks

Required CI should be deterministic, test the actual app/package, and fail on missing tests rather than silently skipping them.

| Surface | Pull-request gate |
|---|---|
| macOS Swift | Swift 6.3+, resolve package, build app/package, run all model-free Swift tests; launch/smoke test app bundle where runner permits |
| Windows | Restore and build WPF app; run all .NET tests; package smoke test |
| Linux | Pin or deliberately track a Zig toolchain only after source compiles on it; build and run unit tests; run headless integration tests under Xvfb where needed |
| Frontend/docs | Bun install from lockfile, TypeScript, ESLint, static export; docs link/structure check |
| Cross-platform contract | Shared cleanup golden fixtures and model manifest schema validation on macOS, Windows, and Linux |

Use changed-path filtering only when it still creates stable required check names. Keep platform workflows separate if needed, but have an aggregate gate fail if a changed platform's tests are skipped. Cache package managers by lockfile hash. Publish logs and test reports on failure.

## Release tracks

1. **PR builds:** CI artifacts for review only; never update `latest`.
2. **Versioned release:** a `vX.Y.Z` tag runs the same tests, then builds native installers and archives, generates SHA-256 checksums and release notes, and attaches all artifacts to a draft release for verification.
3. **Rolling latest:** only after a green merge to `master`, publish a prerelease `latest` channel from that exact SHA. Serialize this workflow so concurrent commits cannot move the tag backward.

## Installer targets

- **macOS:** `.app` in a `.dmg` or zip, Apple Silicon first; sign/notarize when credentials exist. Include model downloads as optional first-run assets, not in the app binary.
- **Windows:** portable zip and an installer; sign when a certificate is available. Include runtime dependencies or document them.
- **Linux:** portable archive plus AppImage or `.deb`; bundle non-system runtime libraries and document the baseline distro.
- **Website:** static download page deployed from green `master`; its build must work without private billing or Convex secrets.

Every release should contain version, commit SHA, platform/architecture, signing status, model licenses, and checksums. A failed platform build must prevent partial releases from being presented as complete.

## Current merge blockers for cleanup PR #145

- Latest CI is red on Linux: the selected Zig master removed `@cImport`, and the GTK C wrappers cannot find `graphene-config.h`.
- The `Vercel` status is red from an account-level integration even though deployment moved to GitHub Pages.
- The PR body says Pages needs `NEXT_PUBLIC_CONVEX_URL` and `NEXT_PUBLIC_APP_URL` Actions configuration. The repository currently exposes neither through `gh variable list` nor the secret list. Resolve whether the static site should be independent of Convex before enabling deployment.
- GitHub reports `REVIEW_REQUIRED`; the existing review is a comment, not an approval.

Do not mark this PR ready to merge until the website build is secret-independent or configured, the Linux policy is explicit and its check outcome is truthful, stale Vercel status is handled, and a maintainer approval is recorded.
