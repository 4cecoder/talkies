# Talkies Mobile - Quick Start Guide

Get up and running with Talkies Mobile in 5 minutes.

## Prerequisites

- Flutter SDK 3.0.0+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- For iOS: Xcode 14.0+, macOS
- For Android: Android Studio with SDK 21+

## Installation

### 1. Navigate to mobile directory
```bash
cd mobile
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Generate code (for JSON serialization)
```bash
flutter pub run build_runner build
```

### 4. Run the app

**For iOS:**
```bash
flutter run -d ios
```

**For Android:**
```bash
flutter run -d android
```

**List available devices:**
```bash
flutter devices
```

## First Launch

1. **Grant microphone permission** when prompted
2. **Tap the microphone button** to start recording
3. **Tap the stop button** to end recording
4. **View your transcript** in the main display
5. **Export** using the SRT/TXT/VTT buttons

## Optional: LLM Enhancement Setup

### Using Ollama

1. **Install Ollama** on your computer or server
   ```bash
   # On macOS/Linux
   curl https://ollama.ai/install.sh | sh
   
   # Download a model
   ollama pull llama2
   
   # Start server
   ollama serve
   ```

2. **In Talkies Mobile:**
   - Open Settings (gear icon)
   - Enable "LLM Enhancement"
   - Select "Ollama" as provider
   - Enter endpoint (e.g., `http://192.168.1.100:11434` if on same network)
   - Tap "Fetch Models" and select a model
   - Choose enhancement mode (Grammar/Concise/Detailed/Creative)

### Using LM Studio

1. **Install LM Studio** ([lmstudio.ai](https://lmstudio.ai))
2. **Load a model** in LM Studio
3. **Start Local Server** in LM Studio
4. **In Talkies Mobile:**
   - Open Settings
   - Enable "LLM Enhancement"
   - Select "LM Studio" as provider
   - Enter endpoint (e.g., `http://192.168.1.100:1234`)
   - Fetch and select a model

## Development

### Hot Reload
While the app is running, make code changes and press `r` in the terminal to hot reload.

### Debug Mode
```bash
flutter run --debug
```

### Release Build
```bash
# iOS
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

### Run Tests
```bash
flutter test
```

### Code Generation (after model changes)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Project Structure Quick Reference

```
lib/
├── main.dart                      # App entry point
├── models/                        # Data models
├── services/                      # Business logic
│   ├── audio_recorder_service.dart
│   ├── settings_service.dart
│   ├── export_service.dart
│   └── llm_service.dart
├── screens/                       # UI screens
│   ├── home_screen.dart
│   └── settings_screen.dart
└── widgets/                       # Reusable widgets
```

## Common Commands

| Task | Command |
|------|---------|
| Install packages | `flutter pub get` |
| Run app | `flutter run` |
| Hot reload | Press `r` in terminal |
| Hot restart | Press `R` in terminal |
| Generate code | `flutter pub run build_runner build` |
| Run tests | `flutter test` |
| Check for issues | `flutter analyze` |
| Format code | `flutter format .` |
| Clean build | `flutter clean` |
| List devices | `flutter devices` |

## Troubleshooting

### "No device found"
- Connect a physical device or start an emulator
- Run `flutter devices` to verify

### "Microphone permission denied"
- Go to device Settings → Apps → Talkies → Permissions
- Enable Microphone permission
- Restart the app

### "LLM connection failed"
- Verify the LLM server is running
- Check the endpoint URL (include http://)
- Ensure your mobile device can reach the server (same network)
- Try the endpoint in a browser first

### Build errors after pulling changes
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Android build issues
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter build apk
```

## Next Steps

- **Read [README.md](README.md)** for detailed feature documentation
- **Check [FEATURES.md](FEATURES.md)** to see what's implemented from desktop versions
- **Explore the code** - it's well-commented and organized
- **Customize settings** - adjust models, languages, and enhancement modes
- **Export transcripts** - try different formats (SRT, TXT, VTT)

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Material Design 3](https://m3.material.io/)
- [Provider State Management](https://pub.dev/packages/provider)

## Support

For issues specific to:
- **Talkies Mobile**: Check this directory's README.md
- **Flutter SDK**: [Flutter Issues](https://github.com/flutter/flutter/issues)
- **Dependencies**: Check the package documentation on [pub.dev](https://pub.dev)

---

**Happy Transcribing! 🎙️**
