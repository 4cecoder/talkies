# Talkies

**Private, on-device dictation for macOS, Windows, Linux, and Android.** Talkies turns speech
into text with local speech recognition and optional local transcript cleanup. After you download
the models you choose, recording, transcription, cleanup, and insertion run on your device. Talkies
has no account, subscription, or hosted transcription service.

Talkies is free and open source under the [MIT License](LICENSE). Model weights and third-party
libraries keep their own licenses; review their notices before redistributing a build.

## Download Talkies

Get the latest tested desktop builds from [GitHub Releases](https://github.com/4cecoder/talkies/releases/latest).
The current `latest` channel is a prerelease. Read the [first-run guide](docs/platforms/first-run-and-troubleshooting.md)
before downloading models or troubleshooting microphone, permission, and insertion issues.

| Platform | Build | Status |
|---|---|---|
| macOS | Native Swift and SwiftUI; WhisperKit; Apple Silicon | Active |
| Windows | Native .NET WPF; Whisper.net | Active |
| Linux | Native Zig app; whisper.cpp; X11 and Wayland | Active; still maturing |
| Android | Native Kotlin app; local Whisper, optional S1-mini cleanup, voice input method | Early access; not yet distributed as a signed release |

On first use, choose and download the local models you need. Model downloads are explicit and
integrity-checked. Android currently downloads Whisper tiny and optional S1-mini separately. See
the platform guides for requirements and the exact setup steps.

## Use Talkies or build it

- [macOS guide](docs/platforms/macos.md) · [Windows guide](docs/platforms/windows.md) ·
  [Linux guide](docs/platforms/linux.md) · [Android guide](docs/platforms/mobile.md)
- [Build and test reference](AGENTS.md) for platform commands and toolchains
- [Contributing guide](CONTRIBUTING.md) for issues, pull requests, and review expectations
- [Documentation index](docs/README.md) for product, architecture, privacy, and release docs
- [Open issues](https://github.com/4cecoder/talkies/issues) for planned and known work
- [Latest releases](https://github.com/4cecoder/talkies/releases/latest) for tested packages

## Repository layout

```text
mac/                 Native macOS app and Swift packages
windows/             Native Windows app and tests
linux/               Native Linux app and Zig build
mobile/android/      Native Kotlin Android app
archive/             Historical prototypes and superseded planning
docs/                Product, architecture, platform, and release guidance
.github/             CI, release automation, issue forms, and templates
```

The public website is maintained separately on the [`website` branch](https://github.com/4cecoder/talkies/tree/website)
and published by GitHub Pages from [`gh-pages`](https://github.com/4cecoder/talkies/tree/gh-pages).
The deprecated Flutter prototype has moved to [`archive/flutter-prototype`](archive/flutter-prototype/README.md);
it is not a supported build target.

## Project status

GitHub Issues and milestones are the canonical work queue; [`docs/ROADMAP.md`](docs/ROADMAP.md)
links to the active milestones instead of maintaining a second backlog. See the
[feature-gap analysis](docs/product/feature-gap-analysis.md) for current platform capabilities
and known gaps.
