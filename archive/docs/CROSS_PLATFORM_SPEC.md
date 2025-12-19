# Talkies Cross-Platform Parity Specification

> Version 1.0 | December 2025

## Overview

This document defines the shared feature matrix, UX conventions, shortcut map, and settings/export schema for Talkies across all platforms (macOS, Windows, Linux, Mobile).

## Feature Matrix

| Feature | macOS | Windows | Linux | Mobile | Priority |
|---------|:-----:|:-------:|:-----:|:------:|:--------:|
| **Core Transcription** |
| Audio Recording | ✓ | ✓ | ✓ | ✓ | P0 |
| Whisper Transcription | ✓ | ✓ | ✓ | ✓ | P0 |
| GPU Acceleration | ✓ Metal | ✓ CUDA | ◐ | - | P1 |
| Multiple Export Formats (VTT/SRT/TXT) | ✓ | ✓ | ✓ | ✓ | P0 |
| **Audio Features** |
| Microphone Selection | ◐ | ✓ | ◐ | ✓ | P1 |
| System Audio Capture | - | ✓ | ◐ | - | P2 |
| Audio Quality Settings | ◐ | ◐ | ◐ | ✓ | P2 |
| Voice Activity Detection | ✓ | ✓ | ◐ | ✓ | P1 |
| **LLM Enhancement** |
| Ollama Provider | ✓ | ✓ | ◐ | - | P1 |
| LM Studio Provider | ◐ | ✓ | ◐ | - | P1 |
| Enhancement Modes | ✓ | ✓ | ◐ | - | P1 |
| Custom Prompts | ✓ | ✓ | ◐ | - | P2 |
| **Input/Output** |
| Global Hotkey | ✓ | ✓ | ◐ | - | P0 |
| Push-to-Talk | ✓ | ✓ | ◐ | ✓ | P1 |
| Text Insertion | ✓ | ✓ | ◐ | ✓ | P1 |
| Text-to-Speech | ✓ | ✓ | ◐ | ✓ | P2 |
| **Settings** |
| Persistent Config | ✓ | ✓ | ✓ | ✓ | P0 |
| Launch at Login | ✓ | ◐ | ◐ | - | P2 |

**Legend**: ✓ = Implemented | ◐ = Partial/In Progress | - = Not Applicable

## Keyboard Shortcuts

### Global Hotkeys

| Action | macOS | Windows | Linux |
|--------|-------|---------|-------|
| Activate (Tap) | Right ⌥ | Right Alt | Right Alt |
| Push-to-Talk (Hold) | Right ⌥ (hold) | Right Alt (hold) | Right Alt (hold) |

### Application Shortcuts

| Action | macOS | Windows | Linux |
|--------|-------|---------|-------|
| Start/Stop Recording | ⌘R | Ctrl+R | Ctrl+R |
| Export Transcript | ⌘E | Ctrl+E | Ctrl+E |
| Open Settings | ⌘, | Ctrl+, | Ctrl+, |
| Quit Application | ⌘Q | Alt+F4 | Ctrl+Q |
| Copy Transcript | ⌘C | Ctrl+C | Ctrl+C |
| Paste | ⌘V | Ctrl+V | Ctrl+V |

### Hotkey Behavior

- **Tap Detection Threshold**: 150ms (configurable 50-500ms)
- **Tap Action**: Toggle recording on/off
- **Hold Action**: Push-to-talk mode (record while held)
- **Visual Feedback**: Status indicator shows current mode

## Settings Schema

All platforms use JSON configuration stored at:
- **macOS**: `~/.talkies/config.json`
- **Windows**: `%USERPROFILE%\.talkies\config.json`
- **Linux**: `~/.config/talkies/config.toml` (XDG compliant)

### Settings Structure

```json
{
  "version": "1.0",
  "transcription": {
    "model": "base",
    "language": "auto",
    "vadEnabled": true,
    "filterEnabled": true
  },
  "audio": {
    "deviceId": null,
    "sampleRate": 16000,
    "channels": 1
  },
  "llm": {
    "provider": "ollama",
    "endpoint": "http://localhost:11434",
    "model": null,
    "enhancementMode": "grammar",
    "temperature": 0.3,
    "topP": 0.9,
    "customPrompt": null
  },
  "hotkey": {
    "tapThreshold": 150,
    "enabled": true
  },
  "output": {
    "insertEnabled": true,
    "ttsEnabled": false,
    "ttsVoice": null,
    "ttsRate": 1.0
  },
  "ui": {
    "theme": "system",
    "compactMode": false,
    "showWaveform": true
  }
}
```

### Whisper Models

| Model | Size | Speed | Accuracy | Use Case |
|-------|------|-------|----------|----------|
| tiny | 75MB | Fastest | Basic | Quick notes |
| base | 142MB | Fast | Good | **Default** |
| small | 466MB | Medium | Better | General use |
| medium | 1.5GB | Slow | High | Professional |
| large | 3GB | Slowest | Best | Critical accuracy |

### Languages

Supported: `auto`, `en`, `es`, `fr`, `de`, `it`, `pt`, `ja`, `zh`

## Export Formats

### VTT (WebVTT)

```
WEBVTT

00:00:00.000 --> 00:00:05.230
First segment of transcribed text.

00:00:05.230 --> 00:00:10.450
Second segment continues here.
```

### SRT (SubRip)

```
1
00:00:00,000 --> 00:00:05,230
First segment of transcribed text.

2
00:00:05,230 --> 00:00:10,450
Second segment continues here.
```

### TXT (Plain Text with Timestamps)

```
[00:00:00.000] First segment of transcribed text.
[00:00:05.230] Second segment continues here.
```

### Plain Text (No Timestamps)

```
First segment of transcribed text.
Second segment continues here.
```

## LLM Enhancement Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| Grammar | Fix spelling, grammar, punctuation | General cleanup |
| Technical | Clean up for documentation/code | Technical writing |
| Concise | Shorten and clarify | Meeting notes |
| Creative | Rephrase with better flow | Content creation |
| Companion | Warm, conversational response | AI assistant |

### Enhancement Prompts

Stored in: `Resources/Prompts/` (embedded) with fallbacks

## UI/UX Conventions

### Color Scheme

| State | Color | Hex |
|-------|-------|-----|
| Ready | Green | #22c55e |
| Recording | Red | #ef4444 |
| Transcribing | Orange | #f97316 |
| Error | Red | #dc2626 |
| Disabled | Gray | #6b7280 |

### Status Indicators

- **Idle**: Subtle pulsing dot
- **Recording**: Animated red circle
- **Processing**: Spinning indicator
- **Complete**: Checkmark flash

### Window Behavior

- **Compact Mode**: 520x140px floating window
- **Full Mode**: Resizable, min 900x600px
- **Always on Top**: Optional for compact mode

### Accessibility

- All interactive elements keyboard accessible
- Screen reader labels for all controls
- High contrast mode support
- Minimum touch target: 44x44px (mobile)

## Platform-Specific Notes

### macOS
- Uses WhisperKit (Apple Silicon optimized)
- Metal GPU acceleration
- Menu bar integration
- Native NSEvent for hotkeys

### Windows
- Uses Whisper.NET (GGML format)
- CUDA GPU acceleration
- System tray integration
- Low-level keyboard hooks

### Linux
- Uses whisper-rs (whisper.cpp bindings)
- CUDA/ROCm/Vulkan GPU options
- X11/Wayland hotkey support
- XDG config paths

### Mobile (Flutter)
- Uses whisper.cpp via FFI
- Platform-native audio APIs
- No global hotkeys
- Touch-optimized UI

## Acceptance Criteria

- [ ] All P0 features implemented on all desktop platforms
- [ ] Settings sync format compatible across platforms
- [ ] Export formats produce identical output
- [ ] Hotkey behavior consistent within 10ms tolerance
- [ ] UI follows platform conventions while maintaining brand identity
