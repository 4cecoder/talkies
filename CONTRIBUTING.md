# Contributing to Talkies

Thanks for helping improve Talkies. It is an open-source, MIT-licensed project maintained in the
open. Contributions of any size are welcome.

## Find or report work

GitHub Issues are the canonical backlog. Before starting a larger change, search the
[open issues](https://github.com/4cecoder/talkies/issues) and comment on the relevant item so work
does not overlap. If the issue is unclear or the change crosses platforms, ask for scope in the
issue before expanding it.

- [Report a reproducible bug](https://github.com/4cecoder/talkies/issues/new?template=bug_report.yml)
- [Propose an improvement](https://github.com/4cecoder/talkies/issues/new?template=feature_request.yml)
- [Browse milestones](https://github.com/4cecoder/talkies/milestones)

Do not attach recordings, private transcripts, credentials, or model weights to public issues.
Include the platform, app version or commit, operating-system version, expected behavior, observed
behavior, and the shortest safe reproduction steps. Redact personal information from logs.

## Choose the active implementation

| Platform | Source | Primary tools |
|---|---|---|
| macOS | `mac/` | Swift 6.3+, SwiftUI, Swift Package Manager |
| Windows | `windows/` | .NET 8, WPF, `uv` for repository Python tooling |
| Linux | `linux/` | Zig master, native system libraries |
| Android | `mobile/android/` | Kotlin, Gradle, Android NDK |

Android is native Kotlin. The former Flutter prototype is archived under
[`archive/flutter-prototype/`](archive/flutter-prototype/README.md) and is not built, tested, or
released. The GitHub Pages website is a separate project on the [`website` branch](https://github.com/4cecoder/talkies/tree/website);
it is intentionally absent from the application source on `master`.

Start with [`AGENTS.md`](AGENTS.md) for the exact build and test commands, then use the relevant
[platform guide](docs/README.md#platform-build-guides). Read
[`docs/architecture/module-volatility.md`](docs/architecture/module-volatility.md) before adding
cross-platform abstractions or moving code between modules.

## Make a focused change

1. Create a branch from current `master` with a descriptive name.
2. Keep the change limited to one behavior or closely related set of fixes.
3. Follow the existing module boundary and platform conventions; do not edit vendored or generated
   code unless the change is specifically about its integration.
4. Run the platform's documented lint, build, and tests. State clearly which commands ran and which
   checks require hardware or model files that were unavailable locally.
5. Update the user or developer documentation when behavior, setup, supported platforms, or build
   requirements change.
6. Open a pull request with the reason for the change, a concise summary, validation evidence, and
   screenshots for visible UI changes.

Review is best-effort. A green build does not replace review of security, privacy, data loss, and
cross-platform behavior.

## Code, models, and licensing

Talkies source is MIT-licensed. Model weights, native inference libraries, and other third-party
components may use different terms. Preserve attribution and license files, do not bundle model
weights without an explicit licensing and distribution review, and do not add a cloud inference
fallback. Model downloads must be explicit, revision-pinned, and integrity-checked.

For a documentation correction, open a small pull request directly. For questions and design
discussion, use [GitHub Discussions](https://github.com/4cecoder/talkies/discussions).
