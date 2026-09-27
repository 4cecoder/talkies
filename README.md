# Talkies

Talkies is a free, open-source voice transcription app. Say something, get text back — on
macOS, Windows, or Linux, with the actual speech-to-text model running on your own
device. Nothing you say is ever uploaded anywhere, there's no account to create, and there's
no subscription: it's a hobby project built because privacy-first, on-device transcription
should just be a normal thing to have.

Talkies is released under the [MIT License](LICENSE). Bundled or downloaded models and other
third-party components keep their own licenses; see their notices before redistributing them.

## Getting Started

- Not sure which platform build is right for you, or what's ready today vs. still in progress?
  Check [`docs/ROADMAP.md`](docs/ROADMAP.md) for current status across platforms, or browse
  [`docs/`](docs/README.md) for everything else (brand kit, architecture diagram).
- Each platform has its own README with setup and build instructions — see the links below.
- Want to contribute? [`CONTRIBUTING.md`](CONTRIBUTING.md) has everything you need to get going,
  and pull requests are very welcome.

## Project Structure

```
talkies/
├── mac/        # macOS native app (Swift/SwiftUI + WhisperKit)
├── windows/    # Windows native app (.NET WPF + WhisperNet)
├── mobile/     # Native Kotlin Android MVP (Flutter prototype retained as legacy reference)
├── linux/      # Linux native app (Zig + whisper.cpp)
└── archive/    # Experimental Python CLI (deprecated)
```

## Platforms

### macOS (`mac/`)
Native macOS application built with Swift and SwiftUI, using WhisperKit for on-device transcription optimized for Apple Silicon.

See [the macOS guide](docs/platforms/macos.md) for detailed documentation.

### Windows (`windows/`)
Native Windows application built with .NET WPF and WhisperNet. Features real-time transcription, LLM enhancement (Ollama/LM Studio), and multi-format export (SRT, VTT, TXT).

See [the Windows guide](docs/platforms/windows.md) for detailed documentation.

### Android (`mobile/android/`) — Kotlin MVP
Android has a native Kotlin app with pinned local Whisper recognition and optional S1-mini cleanup, both using explicitly downloaded and SHA-256-verified models. Recording is in memory; transcripts are editable and copied explicitly. Model downloads require HTTPS, while inference runs locally. Android CI verifies cached ASR followed by S1-mini cleanup with external networking disabled on an API 35 emulator. Full UI-driven recording and clipboard acceptance, persistent history, and signed release distribution remain open. The old Flutter prototype is retained as legacy reference. See [the mobile guide](docs/platforms/mobile.md).

### Linux (`linux/`)
Native Linux application built with Zig and whisper.cpp, with global hotkey support on both X11 and Wayland. Newer and less polished than the macOS/Windows apps.

See [the Linux guide](docs/platforms/linux.md) for detailed documentation.

### Website
The Next.js website source is maintained on the [`website` branch](https://github.com/4cecoder/talkies/tree/website), outside the application source tree. GitHub Pages serves its static export from the [`gh-pages` branch](https://github.com/4cecoder/talkies/tree/gh-pages).

See [the website guide](docs/platforms/website.md) for detailed documentation.
