# Talkies Mobile

A Flutter mobile application for voice transcription that combines the best features from macOS and Windows versions.

## Features

### 🎙️ Audio Recording
- **High-quality recording** from device microphone
- **Real-time audio level visualization**
- **Pause/resume** functionality during recording
- **Recording statistics**: duration, word count, words-per-minute

### 📝 Transcription
- **Model selection**: tiny, base, small, medium, large
- **Language support**: Auto-detect or manual selection
- **Segment-based display** with timestamps
- **Live transcription updates**

### 🧠 LLM Enhancement (Optional)
- **Multi-provider support**:
  - 🦙 **Ollama**: Local LLM inference
  - 🤖 **LM Studio**: OpenAI-compatible endpoints
- **Enhancement modes**:
  - Grammar - Fix spelling and punctuation
  - Concise - Shorten and clarify
  - Detailed - Expand with more information
  - Creative - Rephrase creatively
- **Model discovery**: Automatic detection of available models

### 📤 Professional Export
Export transcripts in multiple formats:
- **SRT** (SubRip) - Video subtitles
- **TXT** (Timestamped Text) - Documents
- **VTT** (WebVTT) - Web video players

### 💾 Persistent Settings
- All settings automatically saved
- Provider and endpoint remembered
- Last used model restored on startup

### 🎨 Modern UI
- **Material Design 3** with dark mode
- **Responsive layout** for different screen sizes
- **Real-time visualization** of audio levels
- **Live statistics** display

## Architecture

### Models (`lib/models/`)
- `transcript_segment.dart` - Transcript segment with timing
- `app_settings.dart` - Application settings model

### Services (`lib/services/`)
- `audio_recorder_service.dart` - Audio recording and management
- `settings_service.dart` - Persistent settings storage
- `export_service.dart` - Multi-format transcript export
- `llm_service.dart` - LLM integration for text enhancement

### Screens (`lib/screens/`)
- `home_screen.dart` - Main recording interface
- `settings_screen.dart` - Configuration screen

### Widgets (`lib/widgets/`)
- `recording_controls.dart` - Record/stop/export buttons
- `transcript_display.dart` - Transcription segment list
- `audio_level_indicator.dart` - Visual audio level meter

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter |
| Language | Dart |
| Audio | record package |
| Storage | shared_preferences |
| HTTP | dio |
| State Management | provider |

## Getting Started

### Prerequisites
- Flutter SDK 3.0.0 or later
- Dart SDK 3.0.0 or later
- For iOS: Xcode 14.0+
- For Android: Android Studio with SDK 21+

### Installation

1. **Clone the repository**
   ```bash
   cd mobile
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate JSON serialization code**
   ```bash
   flutter pub run build_runner build
   ```

4. **Run the app**
   ```bash
   # iOS
   flutter run -d ios
   
   # Android
   flutter run -d android
   ```

## Configuration

### Ollama Setup
```
1. Install Ollama on your server/computer
2. Download model: ollama pull llama2
3. Ensure Ollama is accessible from mobile device
4. In Talkies: Settings → LLM Enhancement
5. Enable enhancement, select Ollama
6. Enter endpoint (e.g., http://192.168.1.100:11434)
7. Fetch models and select one
```

### LM Studio Setup
```
1. Install LM Studio on your server/computer
2. Load a model in LM Studio
3. Start Local Server
4. In Talkies: Settings → LLM Enhancement
5. Enable enhancement, select LM Studio
6. Enter endpoint (e.g., http://192.168.1.100:1234)
7. Fetch models and select one
```

## Permissions

### Android
- `RECORD_AUDIO` - For microphone access
- `WRITE_EXTERNAL_STORAGE` - For saving exports
- `INTERNET` - For LLM API calls

### iOS
- `NSMicrophoneUsageDescription` - Microphone access

## Export Formats

| Format | Timestamp | Use Case |
|--------|-----------|----------|
| SRT | HH:MM:SS,mmm | Video subtitles |
| TXT | [HH:MM:SS.mmm] | Documents |
| VTT | HH:MM:SS.mmm | Web/streaming |

## Future Enhancements

- [ ] **Whisper integration** - On-device transcription using Whisper models
- [ ] **Real-time streaming** - Live transcription as you speak
- [ ] **Cloud sync** - Sync transcripts across devices
- [ ] **Batch processing** - Process multiple audio files
- [ ] **Custom vocabulary** - Add domain-specific terms
- [ ] **Speaker diarization** - Identify different speakers
- [ ] **Translation** - Translate transcripts to other languages

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── transcript_segment.dart
│   │   └── app_settings.dart
│   ├── services/                 # Business logic
│   │   ├── audio_recorder_service.dart
│   │   ├── settings_service.dart
│   │   ├── export_service.dart
│   │   └── llm_service.dart
│   ├── screens/                  # UI screens
│   │   ├── home_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/                  # Reusable widgets
│       ├── recording_controls.dart
│       ├── transcript_display.dart
│       └── audio_level_indicator.dart
├── android/                      # Android-specific code
├── ios/                          # iOS-specific code
├── pubspec.yaml                  # Dependencies
└── README.md                     # This file
```

## Privacy & Security

- All processing happens locally on your device (when LLM is disabled)
- Audio files are stored temporarily and can be deleted
- Settings stored locally in device storage
- No telemetry or tracking
- LLM integration is optional and disabled by default

## Troubleshooting

### No microphone permission
- Grant microphone permission in device settings
- Restart the app after granting permission

### LLM not connecting
- Verify the LLM server is running
- Check the endpoint URL is correct
- Ensure your device can reach the server (same network)
- Check firewall settings on the server

### Export not working
- Grant storage permission if prompted
- Check available storage space
- Try a different export format

## Contributing

This project follows the monorepo structure of Talkies. When making changes:
1. Keep code consistent with macOS and Windows implementations
2. Follow Flutter and Dart style guidelines
3. Test on both iOS and Android
4. Update documentation

## License

[Add your license information here]

## Acknowledgments

Built with inspiration from:
- **macOS version** - WhisperKit integration, UI design
- **Windows version** - Export formats, LLM enhancement patterns
- Flutter community packages

---

**Version**: 1.0.0  
**Status**: Initial Release  
**Platforms**: iOS 12.0+, Android 5.0+ (API 21+)
