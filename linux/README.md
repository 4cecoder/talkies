# Talkies Linux - Voice Transcription

Zig-based voice transcription application for Linux with global hotkey support for both X11 and Wayland.

## Features

- 🎙️ **Voice Recording** - Press Right Alt to record, release to transcribe
- 🚀 **GPU Acceleration** - Vulkan/CUDA support via whisper.cpp
- ⌨️ **Auto-paste** - Inserts transcribed text at cursor automatically
- 🔧 **Highly Configurable** - TOML-based configuration
- 🖥️ **Dual Mode** - Works on both X11 and Wayland (Hyprland)
- 📦 **Lightweight** - <5MB binary, <10 second builds

## Quick Start

```bash
# Build
./run.sh build

# List audio devices
zig-out/bin/talkies audio-list

# Set your microphone
zig-out/bin/talkies audio-set alsa_input.usb-SunplusIT_Inc_Nisheng_M3_W20221116-02.mono-fallback

# Download whisper model
zig-out/bin/talkies models

# Start daemon
zig-out/bin/talkies daemon
```

## Configuration

### Hyprland (Wayland)

For Hyprland users, add this to your `~/.config/hypr/hyprland.conf`:

```bash
# Talkies voice transcription daemon
# Start the daemon on login (optional)
exec-once = /path/to/talkies/linux/zig-out/bin/talkies daemon

# Right Alt hotkey for recording
# Note: This won't work directly - see workaround below
```

**Hyprland Workaround** (until native Wayland hotkey support is added):

Since Hyprland doesn't support press-and-hold hotkeys natively, use this approach:

1. Create a wrapper script `~/.config/hypr/scripts/talkies-record.sh`:

```bash
#!/bin/bash
# Toggle recording with talkies
# Usage: Bind to a key in Hyprland

PIDFILE="/tmp/talkies-recording.pid"

if [ -f "$PIDFILE" ]; then
    # Stop recording
    kill -TERM $(cat "$PIDFILE")
    rm "$PIDFILE"
else
    # Start recording
    /path/to/talkies/linux/zig-out/bin/talkies quick &
    echo $! > "$PIDFILE"
fi
```

2. Make it executable:
```bash
chmod +x ~/.config/hypr/scripts/talkies-record.sh
```

3. Add to hyprland.conf:
```bash
# Toggle recording with Super+Alt+T (easier to use than Right Alt)
bind = $mainMod ALT, T, exec, ~/.config/hypr/scripts/talkies-record.sh

# Or try Right Alt with keycode (may conflict with other apps):
# bind = , code:108, exec, ~/.config/hypr/scripts/talkies-record.sh
```

**Better Hyprland Solution** (Recommended):

Use `submap` for press-and-hold behavior:

```bash
# Right Alt press - start recording
bind = , Alt_R, submap, recording
submap = recording

# Right Alt release - stop recording (handled by talkies daemon)
bind = , Alt_R, submap, reset

# Escape hatch
bind = , escape, submap, reset
submap = reset
```

**Note**: The daemon mode currently works best on X11. Full Wayland/Hyprland press-and-hold support is coming soon.

### X11 (i3, bspwm, GNOME, KDE, etc.)

On X11, the daemon automatically grabs the Right Alt key globally:

```bash
# Just start the daemon
zig-out/bin/talkies daemon

# Press and hold Right Alt to record
# Release to transcribe and paste
```

If Right Alt conflicts with other applications:
- Firefox: `about:config` → disable Right Alt bindings
- foot terminal: Check `~/.config/foot/foot.ini`

### Application Config

Edit `~/.config/talkies/config.toml`:

```toml
[audio]
device = "alsa_input.usb-SunplusIT_Inc_Nisheng_M3_W20221116-02.mono-fallback"

[transcription]
model = "small"       # Options: tiny, base, small, medium, large
language = "en"
threads = 4

[output]
auto_paste = true     # true = paste at cursor, false = copy to clipboard
export_format = "txt" # Options: txt, srt, vtt
```

## Commands

### Daemon Mode
```bash
talkies daemon              # Start background daemon with hotkey
```

### Audio Management
```bash
talkies audio-list          # List available input devices
talkies audio-set <device>  # Set input device
talkies audio               # Test recording (5 seconds)
```

### Transcription
```bash
talkies quick               # One-shot: record → transcribe → paste
talkies transcribe          # Test transcription on anime_16k.wav
talkies models              # Download whisper model from config
```

### Configuration
```bash
talkies config              # Show current configuration
```

## Building from Source

### Dependencies

- **Zig 0.16.0+** - Systems programming language
- **PulseAudio** - Audio recording (`libpulse-simple`, `libpulse`)
- **whisper.cpp** - Speech recognition (`libwhisper`)
- **X11** (X11 only) - Global hotkeys (`libX11`)
- **wl-clipboard** (Wayland) - Clipboard access
- **xdotool** (X11) - Text insertion

### Gentoo/Funtoo

```bash
# Install dependencies
doas emerge -av media-sound/pulseaudio app-accessibility/whisper-cpp x11-libs/libX11 x11-misc/xdotool gui-apps/wl-clipboard

# Build
./run.sh build

# Install (optional)
doas cp zig-out/bin/talkies /usr/local/bin/
```

### Arch Linux

```bash
# Install dependencies
sudo pacman -S zig pulseaudio whisper-cpp libx11 xdotool wl-clipboard

# Build
./run.sh build
```

### Ubuntu/Debian

```bash
# Install dependencies
sudo apt install zig libpulse-dev libwhisper-dev libx11-dev xdotool wl-clipboard

# Build
./run.sh build
```

## Performance

- **Build time**: <10 seconds (debug), <20 seconds (release)
- **Binary size**: ~3-5MB (excluding models)
- **Model loading**: ~2-3 seconds (small model)
- **Transcription**: GPU-accelerated (Vulkan/CUDA)
- **Memory**: ~500MB (with small model loaded)

## GPU Acceleration

Talkies uses whisper.cpp which supports:

- **Vulkan** - Universal GPU acceleration (NVIDIA, AMD, Intel)
- **CUDA** - NVIDIA GPUs
- **ROCm** - AMD GPUs
- **CPU** - Fallback (slower but works everywhere)

GPU is auto-detected. Check daemon output for:
```
ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = NVIDIA GeForce GTX 1070
```

## Troubleshooting

### No audio recorded (0 bytes)
1. Check device is correct: `talkies audio-list`
2. Test recording: `talkies audio`
3. Verify PulseAudio: `pactl list sources short`

### Hotkey not working (X11)
1. Check for conflicts: `xmodmap -pke | grep Alt_R`
2. Try different key in config (future feature)
3. Close Firefox/foot if they grab Right Alt

### Hotkey not working (Wayland/Hyprland)
1. Make sure daemon is running: `ps aux | grep talkies`
2. Check Hyprland config syntax
3. Use the toggle script workaround (see Configuration section)

### Transcription fails
1. Download model: `talkies models`
2. Check model exists: `ls ~/.local/share/talkies/models/`
3. Verify whisper.cpp: `ldd zig-out/bin/talkies | grep whisper`

### GPU not detected
1. Check Vulkan: `vulkaninfo | grep deviceName`
2. Install Vulkan drivers for your GPU
3. Fallback to CPU works automatically (slower)

## Architecture

```
src/
├── main.zig       - CLI entry point, daemon orchestration
├── audio.zig      - PulseAudio recording (16kHz mono PCM)
├── whisper.zig    - whisper.cpp C FFI bindings
├── hotkey.zig     - X11 global hotkey listener
├── clipboard.zig  - Wayland/X11 clipboard (wl-copy/xclip)
├── input.zig      - Text insertion (xdotool)
├── config.zig     - TOML config, XDG directories
└── utils.zig      - Logging, helpers
```

## Comparison to Windows/macOS

| Feature | Linux (Zig) | Windows (.NET) | macOS (Swift) |
|---------|-------------|----------------|---------------|
| Build time | <10s | ~60s | ~30s |
| Binary size | 3-5MB | 50MB | 20MB |
| Dependencies | 1 (whisper.cpp) | 5+ NuGet | 3+ SPM |
| GPU | Vulkan/CUDA/ROCm | CUDA | Metal |
| Hotkey | X11/Wayland | Global | Global |
| Interface | CLI/Daemon | GUI (WPF) | GUI (SwiftUI) |

## Contributing

See [CLAUDE.md](../CLAUDE.md) for development guidelines.

## License

See root LICENSE file.
