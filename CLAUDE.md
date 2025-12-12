# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Talkies is a multi-platform voice transcription application with native apps for macOS, Windows, and a Next.js web frontend.

## Build Commands

### macOS (Swift/SwiftUI)
```bash
cd mac
swift build                    # Debug build
swift build -c release         # Release build
swift test                     # Run tests
swift run Talkies              # Run app
```

### Windows (.NET WPF)
```bash
cd windows/Talkies.Windows
uv run dotnet build            # Debug build
uv run dotnet build -c Release # Release build
uv run dotnet test             # Run tests
uv run dotnet run              # Run app
```

### Frontend (Next.js)
```bash
cd frontend
npm install                    # Install dependencies
npm run dev                    # Development server (localhost:3000)
npm run build                  # Production build
npm run lint                   # Lint code
```

## Architecture

### macOS (`mac/`)
- Swift 6.0 + SwiftUI, targets macOS 15+
- **WhisperKit** for on-device transcription (Apple Silicon optimized)
- **MLX** framework for ML inference on Metal GPU
- Plugin system: `Sources/Talkies/Plugins/` for TTS, image gen, sentiment analysis
- Core services: `AudioRecorder.swift`, `TranscriptionService.swift`

### Windows (`windows/`)
- .NET 8.0 WPF with MVVM pattern
- **Whisper.net** for transcription, **NAudio** for audio capture
- LLM enhancement via Ollama/LM Studio (`Plugins/OllamaEnhancer.cs`, `LmStudioProvider.cs`)
- Main logic in `ViewModels/MainViewModel.cs`
- Services layer: `Services/` directory for audio, transcription, settings, hotkeys

### Frontend (`frontend/`)
- Next.js 16 with App Router, React 19, TypeScript
- Tailwind CSS v4 for styling
- SaaS landing page with auth modals, pricing, dashboard
- Components in `app/components/`, UI primitives in `app/components/ui/`

## Key Patterns

- **Use uv for everything** - Wrap dotnet/npm commands with `uv run` where applicable
- Both desktop apps support multi-format export (SRT, VTT, TXT)
- Both desktop apps integrate with local LLMs (Ollama) for text enhancement
- Privacy-first: all transcription happens locally on-device
