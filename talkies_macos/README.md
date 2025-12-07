# Talkies Swift macOS App

A modern, native Swift macOS application for real-time voice transcription using MLX Whisper, inspired by SuperWhisper's clean and professional design.

## Features

### 🎤 Real-Time Transcription
- Live voice-to-text with sub-second latency
- MLX Whisper integration for Apple Silicon optimization
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

- macOS 14.0 or later
- Apple Silicon (M1/M2/M3/M4) recommended for MLX acceleration
- Python 3.11+ with MLX Whisper installed
- Microphone access permission

## Installation

### 1. Build the Swift App

```bash
# Clone the repository
git clone <repository-url>
cd talkies

# Build the Swift app (no Xcode required)
./build_swift_app.sh
```

### 2. Install Python Dependencies

```bash
# Install using uv (recommended)
cd src
uv sync

# Or install with pip
pip install -r requirements.txt
```

### 3. Run the App

```bash
# Run from the build directory
open Talkies/Talkies.app

# Or install to Applications
cp -R Talkies/Talkies.app /Applications/
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
- **TranscriptionService.swift**: Python bridge for MLX Whisper
- **RecordingView.swift**: Live recording interface
- **TranscriptView.swift**: Transcript viewing and editing
- **SettingsView.swift**: App configuration

### Python Integration

The Swift app communicates with the existing Python MLX Whisper backend through subprocess communication, maintaining compatibility with the original CLI tools while providing a native interface.

## Performance

### Apple Silicon Optimization
- MLX Whisper with Metal GPU acceleration
- Sub-second transcription latency
- Efficient memory usage
- Native audio processing

### Benchmarks
- **Tiny Model**: ~200ms latency
- **Base Model**: ~400ms latency  
- **Medium Model**: ~600ms latency
- **Large Model**: ~800ms latency

## Troubleshooting

### Microphone Permission
If microphone access is denied:
1. Open System Settings > Privacy & Security > Microphone
2. Enable Talkies in the list
3. Restart the app

### Python Integration Issues
If transcription fails:
1. Ensure Python 3.11+ is installed
2. Verify MLX Whisper is installed: `pip install mlx-whisper`
3. Check the Python path in Settings

### Performance Issues
For better performance:
1. Use a smaller model for real-time use
2. Ensure sufficient RAM is available
3. Close other GPU-intensive applications

## Development

### Building from Source

```bash
cd Talkies
swift build
swift run
```

### Project Structure
```
Talkies/
├── Package.swift              # Swift package configuration
├── Sources/
│   └── Talkies/
│       ├── TalkiesApp.swift
│       ├── ContentView.swift
│       ├── AudioRecorder.swift
│       ├── TranscriptionService.swift
│       ├── RecordingView.swift
│       ├── TranscriptView.swift
│       └── SettingsView.swift
└── build_swift_app.sh        # Build script
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

**Talkies** - Blazing-fast real-time voice transcription optimized for Apple Silicon.