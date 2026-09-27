# Changelog

User-facing changes are recorded here. Release tags and the rolling `latest` prerelease are published on [GitHub Releases](https://github.com/4cecoder/talkies/releases).

## 0.1.5 — prerelease (2026-09-27)

This is the current cross-platform release candidate. It is not the first stable release.

### Added

- Native macOS, Windows, and Linux dictation apps with local Whisper speech recognition and optional local S1-mini transcript cleanup.
- Native Android app with on-device Whisper tiny recognition and optional S1-mini cleanup.
- Revision-pinned model downloads with size and SHA-256 verification; models remain outside the desktop application packages.
- Local vocabulary hints, editable transcripts, and TXT/VTT/SRT export support across desktop platforms.
- macOS app ZIP and DMG, Windows portable ZIP and setup installer, and Linux portable tarball and Debian package.
- CI coverage for native builds, model-free tests, cached-model offline inference, and release package smoke checks. Android CI also runs an API 35 emulator acceptance flow with external networking disabled.
- GitHub Pages documentation and product site maintained separately from the application source.

### Known release limitations

- The desktop release artifacts are unsigned; macOS packages are not notarized.
- Android builds are CI artifacts and are not distributed as a signed release APK.
- CI verifies inference and the insertion boundary offline, but does not yet automate a full interactive, microphone-to-focused-app dictation pass on each desktop OS.
- The rolling `latest` release is a prerelease. Stable release publication follows the remaining acceptance and installation checks tracked in [issue #48](https://github.com/4cecoder/talkies/issues/48).
