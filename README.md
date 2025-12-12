# Talkies

Voice transcription application for multiple platforms.

## Project Structure

```
talkies/
├── mac/        # macOS native app (Swift/SwiftUI + WhisperKit)
├── windows/    # Windows native app (.NET WPF + WhisperNet)
├── linux/      # Linux native app (planned)
├── frontend/   # Web app (Next.js)
└── archive/    # Experimental Python CLI (deprecated)
```

## Platforms

### macOS (`mac/`)
Native macOS application built with Swift and SwiftUI, using WhisperKit for on-device transcription optimized for Apple Silicon.

### Windows (`windows/`)
Native Windows application built with .NET WPF and WhisperNet. Features real-time transcription, LLM enhancement (Ollama/LM Studio), and multi-format export (SRT, VTT, TXT).

See [windows/README.md](windows/README.md) for detailed documentation.

### Linux (`linux/`)
Linux native application (planned).

### Web (`frontend/`)
Next.js web application with dashboard and landing page.
