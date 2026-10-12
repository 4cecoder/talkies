# Talkies Linux - Voice Transcription

For model setup, offline checks, and first-run troubleshooting across platforms, see the [first-run guide](first-run-and-troubleshooting.md).

Zig-based voice transcription application for Linux with global hotkey support for both X11 and Wayland.

## Features

- **Push-to-talk dictation**: hold Right Alt, speak, release; or tap to toggle.
- **Types into the focused app** and restores your clipboard afterwards.
- **On-device Whisper** transcription with optional cleanup by the bundled S1-mini model, Ollama, or LM Studio.
- **Desktop integration**: floating indicator, StatusNotifierItem tray (KDE, GNOME with AppIndicator, waybar, AGS), Settings window.
- **X11 and Wayland**: GNOME, KDE Plasma, Hyprland, Sway, and X11 window managers.
- **`talkies doctor`** checks audio, hotkey, paste, clipboard and tray support and names the fix.

Ollama transcript cleanup accepts only `localhost`, `127.0.0.0/8`, or IPv6 `::1` endpoints.
Remote endpoints are rejected and HTTP redirects are disabled to keep transcript requests on
the local machine.

## Local crash diagnostics

If a command exits with an unhandled error, Talkies best-effort writes a local
report containing the error name, timestamp, and available Zig error-return
stack addresses. Reports are stored under
`${XDG_DATA_HOME:-$HOME/.local/share}/talkies/diagnostics/`, with private
directory and file permissions, a 32 KiB report limit, and five rotating files.
Reports are never uploaded. To remove them, quit Talkies and run:

```sh
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/talkies/diagnostics"
```

## Install

Every release on [GitHub Releases](https://github.com/4cecoder/talkies/releases/latest) ships the same
x86_64 build in several formats. It bundles Talkies' Whisper/llama.cpp runtimes, so only standard
desktop libraries (GTK 4, PulseAudio client or pipewire-pulse, SQLite, D-Bus) come from your
distribution. Minimum: glibc 2.35 and GTK 4.6 (Ubuntu 22.04, Debian 12, RHEL 9 or newer) and a CPU
with AVX2 (2013 or newer). CI installs each package on the distributions below before every release.

| Distribution | Package | Install |
| --- | --- | --- |
| Ubuntu 22.04+, Debian 12+, Mint, Pop!_OS | `.deb` | `sudo apt install ./Talkies-Linux-<version>.deb` |
| Fedora, RHEL / Alma / Rocky 9+ | `.rpm` | `sudo dnf install ./Talkies-Linux-<version>.rpm` |
| openSUSE Tumbleweed / Leap | `.rpm` | `sudo zypper install --allow-unsigned-rpm ./Talkies-Linux-<version>.rpm` |
| Arch, Manjaro, EndeavourOS | `.pkg.tar.zst` or AUR `PKGBUILD` | `sudo pacman -U ./Talkies-Linux-<version>.pkg.tar.zst` |
| Gentoo | `talkies-bin` ebuild | see below |
| Anything else (glibc) | `.tar.gz` | `tar xf Talkies-Linux-<version>.tar.gz && sudo ./talkies-*/install.sh` |

Then start **Talkies** from your app menu (or run `talkies daemon`) and run `talkies doctor` if
anything does not work. The first start downloads the Whisper model once (about 150 MB); after that
Talkies runs fully offline.

The packages install a udev rule that gives the logged-in user access to `/dev/uinput`, which Talkies
uses to type text. On Wayland, the Right Alt hotkey additionally needs read access to keyboards:
`sudo usermod -aG input $USER`, then log in again (or bind `talkies-hotkey.sh` in your compositor).

**Arch (AUR-style build).** Download `PKGBUILD` from the release and run `makepkg -si` next to it.

**Gentoo.** Put the release's `talkies-bin-<version>.ebuild` in a local overlay and emerge it:

```bash
doas mkdir -p /var/db/repos/local/app-accessibility/talkies-bin
doas cp talkies-bin-<version>.ebuild /var/db/repos/local/app-accessibility/talkies-bin/
cd /var/db/repos/local/app-accessibility/talkies-bin && doas ebuild talkies-bin-<version>.ebuild manifest
doas emerge --ask app-accessibility/talkies-bin   # USE="X wayland" pulls xclip / wl-clipboard
```

**User-only install (no root).** `./talkies-*/install.sh` without sudo installs into `~/.local`;
typing into apps then needs `/dev/uinput` access, which the root install sets up.

**Uninstall.** Use your package manager (`apt remove talkies`, `dnf remove talkies`,
`pacman -R talkies`, `emerge --depclean talkies-bin`) or `./talkies-*/install.sh --uninstall`.
Settings (`~/.config/talkies`) and models (`~/.local/share/talkies`) are kept.

### Build from source

Needs Zig master (0.18.0-dev), GTK 4 and PulseAudio development files, and the pinned whisper.cpp and
llama.cpp, which `packaging/linux/build-native-deps.sh` builds:

```bash
packaging/linux/build-native-deps.sh          # once; installs into /usr/local
cd linux && zig build -Doptimize=ReleaseSafe   # zig-out/bin/talkies
zig build test                                 # unit tests by layer
scripts/install.sh --restart                   # developer install + restart the daemon
```

To produce the release packages locally: `zig build -Doptimize=ReleaseSafe -Dversion=X.Y.Z`, then
`VERSION=vX.Y.Z APP_VERSION=X.Y.Z packaging/linux/package.sh` (writes `linux/dist/`).

Whisper models are pinned to a [specific upstream revision](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1), checked against exact size and SHA-256, and installed from a temporary file. Talkies verifies the cached model before each load; verified models work offline.

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
vocabulary_prompt = "Talkies, WhisperKit, S1-mini" # Optional local recognition hints; max 400 characters

[output]
auto_paste = true     # true = paste at cursor, false = copy to clipboard
```

Linux currently inserts the transcript at the cursor or copies it to the clipboard.
To explicitly export a WAV file with local Whisper timestamps, run:

```sh
talkies transcribe speech.wav --format vtt --output speech.vtt
```

The format can be `txt`, `vtt`, or `srt`. Export writes raw ASR segments without
inserting them or touching the clipboard; the chosen output file must not already
exist. The legacy `export_format` config key is ignored.

The vocabulary prompt is passed to the on-device whisper.cpp recognizer. It supports names
and uncommon terms and is stored in this local config file.

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

- **Zig master (0.17.0-dev or newer)** - The Linux build follows current Zig development and uses build-system C translation.
- **PulseAudio** - Audio recording (`libpulse-simple`, `libpulse`)
- **whisper.cpp** - Speech recognition (`libwhisper`)
- **X11** (X11 only) - Global hotkeys (`libX11`)
- **wl-clipboard** (Wayland) - Clipboard access (install `wl-clipboard` package)

**No xdotool needed!** - Uses native Linux uinput for keyboard simulation

### Gentoo/Funtoo

```bash
# Install dependencies
doas emerge -av media-sound/pulseaudio app-accessibility/whisper-cpp x11-libs/libX11 gui-apps/wl-clipboard

# Build
./run.sh build

# Setup uinput permissions (for text pasting)
doas modprobe uinput
echo 'KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"' | doas tee /etc/udev/rules.d/99-uinput.rules
doas udevadm control --reload-rules && doas udevadm trigger
doas usermod -aG input $USER  # Logout and login for this to take effect

# Install (optional)
doas cp zig-out/bin/talkies /usr/local/bin/
```

### Arch Linux

```bash
# Install dependencies
sudo pacman -S zig pulseaudio whisper-cpp libx11 wl-clipboard

# Build
./run.sh build

# Setup uinput permissions (for text pasting)
sudo modprobe uinput
echo 'KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-uinput.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG input $USER  # Logout and login for this to take effect
```

### Ubuntu/Debian

```bash
# Install dependencies
sudo apt install zig libpulse-dev libwhisper-dev libx11-dev wl-clipboard

# Build
./run.sh build

# Setup uinput permissions (for text pasting)
sudo modprobe uinput
echo 'KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-uinput.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG input $USER  # Logout and login for this to take effect
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

### Port already in use (AddressInUse error)
If you see `error: AddressInUse` when starting the daemon:

```bash
# Clean up stuck processes and free ports
zig build cleanup

# Or manually:
./scripts/cleanup.sh
```

This kills any zombie `arecord` processes and frees port 6789 (WebSocket daemon).

### Text not pasting (Permission denied on /dev/uinput)
1. Check uinput module loaded: `lsmod | grep uinput`
2. Load if needed: `doas modprobe uinput`
3. Check permissions: `ls -la /dev/uinput`
4. Add udev rule (see installation instructions above)
5. Add yourself to `input` group: `doas usermod -aG input $USER`
6. **Important**: Logout and login for group changes to take effect
7. Verify group membership: `groups | grep input`

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
4. Reload Hyprland config: `hyprctl reload`

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

See [CLAUDE.md](../../CLAUDE.md) for development guidelines.

## License

See root LICENSE file.
