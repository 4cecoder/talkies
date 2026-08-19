# Talkies Docs

Project-level documentation that isn't tied to a specific platform's codebase.

## In this folder

- **[ROADMAP.md](ROADMAP.md)** — Open and in-progress work items, migrated from the project's former internal issue tracker.
- **[BRAND_KIT.md](BRAND_KIT.md)** — Brand guidelines: colors, typography, logo usage, and design tokens. Brand asset *files* (logos, icons, color exports) live in [`/branding`](../branding), not here.
- **[CRASHLYTICS.md](CRASHLYTICS.md)** — Crash reporting API: the request/response format for the crash-report ingestion endpoint.
- **[architecture/talkies_business_architecture.mmd](architecture/talkies_business_architecture.mmd)** and **[architecture/talkies_business_architecture.png](architecture/talkies_business_architecture.png)** — Business/system architecture diagram (Mermaid source and rendered PNG).

## Platform-specific docs

Each platform keeps its own documentation alongside its code, since those docs are tightly coupled to that platform's build tooling and often linked from within the platform's own files:

- [`mac/README.md`](../mac/README.md) — macOS (Swift/SwiftUI) app
- [`windows/README.md`](../windows/README.md) — Windows (.NET WPF) app
- [`mobile/README.md`](../mobile/README.md) (see also `QUICKSTART.md`, `FEATURES.md`, `IMPLEMENTATION_NOTES.md` in the same folder) — Flutter mobile app
- [`linux/README.md`](../linux/README.md) (see also `QUICKSTART.md`, `SHIPPING.md`, `DAEMON_MODE.md`, and `linux/docs/`) — Linux app
- [`frontend/README.md`](../frontend/README.md) — Next.js web frontend
