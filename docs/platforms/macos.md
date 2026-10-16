# Talkies Swift macOS App

A native Swift macOS dictation app using Phonon-2 on Core ML for English speech recognition, WhisperKit as the multilingual fallback, and optional S1-mini cleanup through llama.cpp.

## Features

### 🎤 Real-Time Transcription
- Live voice-to-text using Phonon-2 (English, default) with an on-device WhisperKit fallback
- Optional S1-mini transcript cleanup using the local Q4_K_M GGUF model
- CPU-only cleanup inference through llama.cpp
- Voice Activity Detection (VAD) for efficient processing
- Real-time audio level monitoring

### 🎨 Modern SwiftUI Interface
- Clean, professional design inspired by SuperWhisper
- Native macOS controls and interactions
- Smooth animations and transitions
- Dark mode support
- Responsive layout for different screen sizes

### 📊 Live Statistics
- Word count and words-per-minute tracking
- Segment counting
- Recording duration
- Real-time audio visualization

### 💾 Export Options
- WebVTT (.vtt) format for video subtitles
- SubRip (.srt) format for compatibility
- Plain text (.txt) for easy sharing
- Native macOS file picker

### ⚙️ Customizable Settings
- Multiple Whisper model sizes (tiny to large-v3-turbo)
- Language selection with auto-detection
- Audio quality settings
- Hallucination filter
- Export preferences

## Requirements

- macOS 15+
- Apple Silicon recommended for WhisperKit performance
- Swift 6.3 or newer
- Microphone access permission

## Quick Start

```bash
./run.sh          # Build and run
./run.sh build    # Debug build only
./run.sh release  # Release build
./run.sh clean    # Clean build directory
```

## Manual Build

Use Swift 6.3 or newer from your active toolchain:

```bash
swift --version
swift build
swift run Talkies
```

The package manifest requires Swift tools 6.3. CI and release builds use Swift 6.3.3.

## Install and update from a release

Verify the macOS DMG against `SHA256SUMS`, open it, and drag `Talkies.app` to
`/Applications`. For a manual update, quit Talkies, open the newer DMG, and replace the existing
`/Applications/Talkies.app` with the new copy. Model weights and preferences are stored outside the
app bundle, so replacing the app does not delete them. ZIP downloads contain the same app bundle if
you prefer to install without mounting a DMG.

## Local crash diagnostics

Talkies may write a small local exception report containing only the exception
name, reason, timestamp, and stack trace. Reports are stored under
`~/Library/Application Support/Talkies/Diagnostics/`, limited to 32 KiB each,
and rotated to keep at most five reports. They are never uploaded. To delete
them, quit Talkies and remove that `Diagnostics` folder in Finder or with:

```sh
rm -rf "$HOME/Library/Application Support/Talkies/Diagnostics"
```

## Usage

### First Time Setup

1. Launch Talkies from your Applications folder
2. Grant microphone permission when prompted
3. Configure your preferred settings in the Settings tab

### Recording and Transcription

1. **Start Recording**: Click the red record button or press the global shortcut
2. **Speak Clearly**: The app will transcribe your speech in real-time
3. **Monitor Progress**: Watch the live transcript and statistics
4. **Stop Recording**: Click the stop button when finished
5. **Export**: Save your transcript in your preferred format

### Keyboard Shortcuts

- `⌘ + R`: Start/Stop recording
- `⌘ + E`: Export transcript
- `⌘ + ,`: Open settings
- `⌘ + W`: Close window (keep recording in background)

## Architecture

### Swift Components

- **TalkiesApp.swift**: Main app entry point
- **ContentView.swift**: Primary interface with sidebar navigation
- **AudioRecorder.swift**: AVFoundation-based audio recording
- **TranscriptionService.swift**: transcription pipeline over the speech-runtime chain
- **TalkiesInference**: speech-runtime chain (`SpeechRecognizerChain`), Phonon-2 and WhisperKit adapters, S1-mini model storage and llama.cpp CPU adapter
- **RecordingView.swift**: Live recording interface
- **TranscriptView.swift**: Transcript viewing and editing
- **SettingsView.swift**: App configuration

## Performance

Speech recognition and transcript cleanup run on-device. S1-mini cleanup uses the CPU and its model is downloaded on first use; after download, cleanup works offline.

## Troubleshooting

See the shared [first-run and troubleshooting guide](first-run-and-troubleshooting.md) for model setup, Accessibility approval, offline checks, and cache recovery.

### Microphone Permission
If microphone access is denied:
1. Open System Settings > Privacy & Security > Microphone
2. Enable Talkies in the list
3. Restart the app

### Speech engines

Settings → General → **Speech Engine** chooses between:

- **Phonon-2 (English), Whisper fallback** (default). Talkies runs [Phonon-2](https://huggingface.co/FermionResearch/Phonon-2-CoreML)
  through Fermion Research's [`phonon-coreml`](https://github.com/fermionresearch/phonon-coreml) Swift package (pinned to 1.1.2).
  If Phonon-2 is missing, fails to load, or fails a transcription, the same recording is transcribed with WhisperKit.
- **Whisper (multilingual)**: WhisperKit `openai_whisper-base` only. Use this for languages other than English.

The first Phonon-2 use downloads about 345 MB from a pinned Hugging Face revision into
`~/Library/Application Support/Talkies/Models/Phonon-2-CoreML-<revision>/`, with every file checked against
its size and SHA-256 from the repository's `SHA256SUMS`. macOS then compiles the encoder for the Neural Engine
once, which took about five minutes on an M-series test Mac. The compiled copy is cached in
`~/Library/Caches/phonon-coreml/`. While that one-time preparation runs, Talkies uses an already-installed
Whisper model so dictation isn't blocked. Later loads take a few seconds.

Phonon-2 has no vocabulary prompt, so personal vocabulary affects only the Whisper path and S1-mini cleanup.
Phonon-2 weights are CC BY 4.0 (Fermion Research, derived from NVIDIA Parakeet TDT 0.6B v3). The license and
NOTICE files are downloaded next to the weights. `phonon-coreml` is Apache 2.0 and links a prebuilt static
TDT decoder library (`PhononTDT.xcframework`) supplied by the package.

To run the offline Phonon-2 acceptance test against a provisioned bundle:

```sh
cd mac && TALKIES_PHONON_MODEL_DIR=/path/to/Phonon-2-CoreML swift test --filter PhononAcceptanceTests
```

### S1-mini download issues
S1-mini requires a one-time model download. Connect to the network, retry cleanup, and then the app can use the verified local model offline. If cleanup still fails, Talkies inserts the raw WhisperKit transcript.

### Performance Issues
For better performance, select a smaller WhisperKit speech model and leave enough memory for the local speech model and S1-mini's CPU context.

## Development

### Building from Source

```bash
./run.sh build    # Debug build
./run.sh          # Build and run
```

### Project Structure
```
mac/
├── Package.swift              # Swift package configuration
├── run.sh                     # Build/run helper script
├── Sources/
│   └── Talkies/
│       ├── TalkiesApp.swift
│       ├── ContentView.swift
│       ├── AudioRecorder.swift
│       ├── TranscriptionService.swift
│       ├── RecordingView.swift
│       ├── TranscriptView.swift
│       └── SettingsView.swift
└── README.md
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and feature requests:
- Create an issue on GitHub
- Check the troubleshooting guide
- Review the documentation

---

**Talkies** - Local voice dictation with optional offline transcript cleanup.
