# Implementation Notes - Talkies Mobile

## Overview
This document provides technical notes about the implementation of Talkies Mobile, created as a Flutter application that combines the best features from the macOS (Swift) and Windows (.NET) versions.

## Implementation Date
- **Created**: December 15, 2024
- **Flutter Version**: 3.0.0+
- **Dart Version**: 3.0.0+

## Design Decisions

### 1. State Management - Provider Pattern
**Decision**: Use Provider for state management
**Rationale**: 
- Simple and well-documented
- Official Flutter recommendation for medium-sized apps
- Easy to understand for developers familiar with other platforms
- Minimal boilerplate compared to BLoC or Redux

### 2. Audio Recording - `record` Package
**Decision**: Use the `record` package for audio recording
**Rationale**:
- Cross-platform (iOS & Android)
- Active maintenance
- Support for amplitude/level monitoring
- Multiple audio formats (AAC, WAV, etc.)
- Similar capabilities to AVFoundation (macOS) and NAudio (Windows)

### 3. No Whisper Integration (Yet)
**Decision**: Placeholder implementation for transcription
**Rationale**:
- Whisper integration on mobile requires significant optimization
- On-device models can be large (100MB+ for base model)
- Performance concerns on lower-end devices
- Marked as future enhancement with detailed TODO comments
- Structure ready for integration when available

**Future Options**:
- `whisper_flutter` package (when stable)
- Cloud-based transcription API
- Hybrid approach (on-device for small models, cloud for larger)

### 4. JSON Serialization - `json_serializable`
**Decision**: Use code generation for JSON serialization
**Rationale**:
- Type-safe serialization/deserialization
- Reduced boilerplate code
- Compile-time error checking
- Consistent with desktop implementations' approach to data models

### 5. Architecture - Clean Architecture Lite
**Decision**: Separate concerns into Models, Services, Screens, Widgets
**Rationale**:
- Clear separation of business logic (Services) from UI (Screens/Widgets)
- Models are pure data structures
- Easy to test individual components
- Mirrors structure of macOS and Windows implementations
- Scalable for future enhancements

## Key Implementation Details

### Audio Level Monitoring
```dart
// Similar to AudioRecorder.swift's audio tap handling
_amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
  final amplitude = await _recorder.getAmplitude();
  _audioLevel = amplitude.current / amplitude.max;
  notifyListeners();
});
```

### Export Format Implementation
The export service mirrors the Windows TranscriptExporter pattern:
- SRT: `HH:MM:SS,mmm --> HH:MM:SS,mmm` (comma separator)
- VTT: `HH:MM:SS.mmm --> HH:MM:SS.mmm` (dot separator)
- TXT: `[HH:MM:SS.mmm] text` (bracketed timestamps)

### Settings Persistence
Uses SharedPreferences (similar to UserDefaults on macOS):
- JSON serialization of entire settings object
- Auto-save on every settings change
- Default values defined in model

### LLM Integration
HTTP-based integration with Ollama/LM Studio:
- Same prompts as Windows implementation
- Support for multiple enhancement modes
- Error handling with user-friendly messages
- Model discovery via API

## Platform-Specific Considerations

### iOS
- **Microphone Permission**: Defined in Info.plist
- **Audio Session**: Handled by `record` package
- **Background Audio**: Not currently supported (foreground only)

### Android
- **Permissions**: RECORD_AUDIO, WRITE_EXTERNAL_STORAGE in AndroidManifest.xml
- **Runtime Permissions**: Handled via `permission_handler` package
- **File Storage**: Uses app-specific temporary directory

## Testing Strategy

### Current Testing
- Basic widget test to verify app structure
- Manual testing of recording flow
- Settings persistence testing

### Recommended Future Tests
1. **Unit Tests**:
   - Export format generation (SRT/VTT/TXT)
   - Timestamp formatting
   - Settings serialization/deserialization
   
2. **Widget Tests**:
   - Recording controls interaction
   - Settings screen navigation
   - Transcript display rendering
   
3. **Integration Tests**:
   - End-to-end recording flow
   - Export and share functionality
   - LLM enhancement flow

## Known Limitations

### 1. Transcription
- **Current**: Placeholder mock implementation
- **Limitation**: No actual speech-to-text
- **Future**: Whisper integration or cloud API

### 2. Offline LLM
- **Current**: Requires network access to LLM server
- **Limitation**: No on-device LLM
- **Future**: Could integrate mobile LLM runtime (e.g., llama.cpp mobile)

### 3. Background Recording
- **Current**: Foreground only
- **Limitation**: Recording stops when app backgrounded
- **Future**: Background audio session support

### 4. Real-time Transcription
- **Current**: Transcription after recording completes
- **Limitation**: No streaming transcription
- **Future**: Streaming API integration

## Performance Considerations

### Memory Usage
- Audio recording: ~10-20MB during active recording
- Settings: <1MB in SharedPreferences
- Transcripts: Depends on length, typically <1MB per hour

### Battery Impact
- Recording: Moderate (microphone + processing)
- LLM Enhancement: Low (network-based)
- Idle: Minimal (no background processes)

### Storage
- Audio files: Temporary, ~1-2MB per minute
- Transcripts: Exported files only (user-controlled)
- Settings: <100KB

## Comparison with Desktop Versions

| Feature | macOS | Windows | Mobile |
|---------|-------|---------|--------|
| Audio Recording | ✅ AVFoundation | ✅ NAudio | ✅ record package |
| Transcription | ✅ WhisperKit | ✅ WhisperNet | ⏳ Placeholder |
| LLM Enhancement | ✅ Ollama | ✅ Ollama/LM Studio | ✅ Ollama/LM Studio |
| Export Formats | ⚠️ Limited | ✅ SRT/VTT/TXT | ✅ SRT/VTT/TXT |
| Settings Persist | ✅ UserDefaults | ✅ JSON file | ✅ SharedPreferences |
| Hotkeys | ✅ Global | ✅ Global | ❌ N/A |
| Text Injection | ✅ Accessibility | ✅ SendInput | ❌ N/A |
| TTS | ✅ NSSpeech | ✅ System.Speech | ⏳ Future |

Legend: ✅ Implemented | ⏳ Planned | ⚠️ Partial | ❌ Not Applicable

## Migration Notes

### From Desktop to Mobile
If users are migrating from desktop versions:
1. Settings are not shared (different platforms)
2. Transcripts must be exported and transferred manually
3. LLM endpoints need to be accessible from mobile network
4. Some desktop-only features unavailable (hotkeys, text injection)

### Future Sync
Could implement:
- Cloud settings sync
- Transcript cloud storage
- Cross-platform history

## Dependencies Overview

### Production Dependencies
- `record: ^5.0.0` - Audio recording
- `provider: ^6.1.0` - State management
- `path_provider: ^2.1.0` - File paths
- `shared_preferences: ^2.2.0` - Settings storage
- `permission_handler: ^11.0.0` - Permissions
- `share_plus: ^7.2.0` - Native sharing
- `dio: ^5.4.0` - HTTP client
- `json_annotation: ^4.8.1` - JSON serialization

### Development Dependencies
- `flutter_lints: ^3.0.0` - Linting
- `build_runner: ^2.4.6` - Code generation
- `json_serializable: ^6.7.1` - JSON code gen

## Contributing Guidelines

When adding new features:
1. Follow existing architecture (Models/Services/Screens/Widgets)
2. Use Provider for state management
3. Add JSON serialization for new models
4. Update documentation (README, FEATURES, this file)
5. Add appropriate TODO comments for future work
6. Test on both iOS and Android
7. Follow Flutter/Dart style guide

## References

### Desktop Implementations
- **macOS**: `/mac/Sources/Talkies/`
- **Windows**: `/windows/Talkies.Windows/`

### Flutter Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Record Package](https://pub.dev/packages/record)

### Related Technologies
- [Whisper by OpenAI](https://github.com/openai/whisper)
- [Ollama](https://ollama.ai/)
- [LM Studio](https://lmstudio.ai/)

---

**Last Updated**: December 15, 2024
**Status**: Production-ready foundation, Whisper integration pending
**Maintainer**: Talkies Team
