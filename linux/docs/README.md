# Talkies Linux - Zig Implementation

Clean, minimal CLI application for voice transcription and text insertion on Linux.

## Features

- **🎙️ Audio Recording** - PulseAudio-based 16kHz mono PCM recording
- **🗣️ Speech Transcription** - On-device transcription via whisper.cpp
- **📋 Clipboard Integration** - X11 and Wayland support
- **⌨️ Text Insertion** - Automatic paste after transcription
- **⚙️ Configuration** - TOML-based config at `~/.config/talkies/config.toml`

## Quick Start

### Using the Helper Script

The easiest way to build and run Talkies is using `run.sh`:

```bash
# Check dependencies
./run.sh deps

# Build and test
./run.sh build
./run.sh test

# Run commands
./run.sh audio          # Test microphone
./run.sh help           # Show help

# Install to ~/.local/bin
./run.sh install

# Development mode (auto-rebuild on changes)
./run.sh dev
```

See `./run.sh help` for all available commands.

### Manual Installation

**Requirements:**
- Zig 0.16.0+
- PulseAudio development libraries
- xclip (for X11) or wl-clipboard (for Wayland)
- xdotool (for text insertion)

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install libpulse-dev xclip wl-clipboard xdotool

# Install dependencies (Arch Linux)
sudo pacman -S libpulse xclip wl-clipboard xdotool

# Build
cd linux
zig build

# Install (optional)
sudo cp zig-out/bin/talkies /usr/local/bin/
```

### Usage

```bash
# Quick workflow: Record → Transcribe → Paste
talkies quick

# Record audio to file
talkies record

# Download whisper models
talkies models

# Show configuration
talkies config

# Test audio devices
talkies audio
```

## Configuration

Default config location: `~/.config/talkies/config.toml`

```toml
[transcription]
model = "base"           # Model size: tiny, base, small, medium, large
language = "en"          # Language code
threads = 4              # CPU threads for transcription

[output]
auto_paste = true        # Automatically paste after transcription
export_format = "txt"    # Export format: txt, srt, vtt
```

## Architecture

### Core Modules

- **main.zig** (152 LOC) - CLI framework and command routing
- **audio.zig** (280 LOC) - PulseAudio recording with WAV export
- **whisper.zig** (312 LOC) - whisper.cpp C FFI for transcription
- **clipboard.zig** (140 LOC) - Cross-platform clipboard (X11/Wayland)
- **input.zig** (96 LOC) - Text insertion via xdotool
- **config.zig** (317 LOC) - TOML configuration management
- **utils.zig** (79 LOC) - Logging and XDG paths

**Total:** ~1,376 LOC

### Data Flow

```
User runs: talkies quick
  ↓
Audio.startRecording() → 16kHz mono PCM to WAV
  ↓
[User presses Ctrl+C]
  ↓
Audio.stopRecording() → Finalize WAV file
  ↓
Whisper.transcribe(wav_path) → Extract text
  ↓
Clipboard.copy(text) → Save to clipboard
  ↓
Input.paste() → Simulate Ctrl+V
  ↓
Cleanup temp files
```

## Build Performance

| Metric | Value |
|--------|-------|
| Build time (debug) | <5 seconds |
| Build time (release) | <10 seconds |
| Binary size (debug) | ~2 MB |
| Binary size (release) | <500 KB |
| Dependencies | 1 (whisper.cpp) |
| Lines of code | ~1,376 |

## Comparison with Rust/Tauri

| Metric | Rust/Tauri | Zig |
|--------|-----------|-----|
| Build time | 2-5 minutes | <10 seconds |
| Binary size | 50-100 MB | <5 MB |
| Dependencies | 150+ | 1 |
| LOC | ~5000+ | ~1,376 |
| Interface | GUI (React) | CLI only |
| Startup time | ~500ms | <100ms |

## Development

```bash
# Run tests
zig build test

# Build and run
zig build run -- help

# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseFast
```

## Troubleshooting

### Audio Issues

**Problem:** "PulseAudio connection failed"
```bash
# Check PulseAudio is running
pulseaudio --check
# Start if not running
pulseaudio --start
```

**Problem:** "No audio recorded"
```bash
# Test microphone
talkies audio
# List audio devices
pactl list sources short
```

### Clipboard Issues

**Problem:** "xclip not found" (X11)
```bash
sudo apt install xclip
```

**Problem:** "wl-copy not found" (Wayland)
```bash
sudo apt install wl-clipboard
```

### Text Insertion Issues

**Problem:** "xdotool not found"
```bash
sudo apt install xdotool
```

**Problem:** "Paste doesn't work in some apps"
- Try direct typing mode (implemented in input.zig)
- Some apps require focus delay (already implemented)

## License

See root LICENSE file for details.

## Contributing

See ARCHITECTURE.md for design details and BUILD.md for build instructions.
