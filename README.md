# Talkies

Talkies is a free, open-source voice transcription app. Say something, get text back — on
macOS, Windows, Linux, or mobile, with the actual speech-to-text model running on your own
device. Nothing you say is ever uploaded anywhere, there's no account to create, and there's
no subscription: it's a hobby project built because privacy-first, on-device transcription
should just be a normal thing to have.

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
├── mobile/     # Mobile app (Flutter for iOS & Android)
├── linux/      # Linux native app (Zig + whisper.cpp)
├── frontend/   # Web app (Next.js) — project site, live browser demo, and docs
└── archive/    # Experimental Python CLI (deprecated)
```

## Platforms

### macOS (`mac/`)
Native macOS application built with Swift and SwiftUI, using WhisperKit for on-device transcription optimized for Apple Silicon.

See [mac/README.md](mac/README.md) for detailed documentation.

### Windows (`windows/`)
Native Windows application built with .NET WPF and WhisperNet. Features real-time transcription, LLM enhancement (Ollama/LM Studio), and multi-format export (SRT, VTT, TXT).

See [windows/README.md](windows/README.md) for detailed documentation.

### Mobile (`mobile/`)
Flutter mobile application for iOS and Android. Combines the best features from macOS and Windows versions with audio recording, transcription display, LLM enhancement, and multi-format export (SRT, VTT, TXT). Still in progress — see [`docs/ROADMAP.md`](docs/ROADMAP.md) for current status.

See [mobile/README.md](mobile/README.md) for detailed documentation.

### Linux (`linux/`)
Native Linux application built with Zig and whisper.cpp, with global hotkey support on both X11 and Wayland. Newer and less polished than the macOS/Windows apps.

See [linux/README.md](linux/README.md) for detailed documentation.

### Web (`frontend/`)
Next.js site with the project homepage, a live in-browser transcription demo, and onboarding docs to help you pick a platform.

See [frontend/README.md](frontend/README.md) for detailed documentation.
