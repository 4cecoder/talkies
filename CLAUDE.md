# Agent notes for Talkies

Talkies is an open-source, local-first dictation app with native clients for macOS, Windows, Linux,
and Android. Model downloads are explicit; recording, inference, cleanup, and text insertion run
on-device after setup. There is no hosted speech or transcript-cleanup service.

Before changing code:

1. Read [`AGENTS.md`](AGENTS.md) for supported platforms, toolchains, commands, and coding rules.
2. Read [`docs/architecture/module-volatility.md`](docs/architecture/module-volatility.md) before
   changing library boundaries or introducing shared abstractions.
3. Check the relevant platform guide under [`docs/platforms/`](docs/platforms/) and open GitHub
   issues before starting larger work.

## Repository boundaries

- `mac/`, `windows/`, `linux/`, and `mobile/android/` contain active application implementations.
- `archive/` contains historical prototypes and planning; do not treat it as current product code.
- The website is maintained on the separate [`website` branch](https://github.com/4cecoder/talkies/tree/website)
  and published by GitHub Pages. Do not add its source or a server backend to the application branch.
- GitHub Issues and milestones are the canonical work queue.

Use platform-native APIs and follow the tests and dependency boundaries already present. Do not
bundle model weights, commit user data, bypass SHA-256 model checks, or add a network fallback to
local inference. Preserve upstream license and attribution files.
