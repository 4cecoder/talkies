# Talkies Linux - Dependency Installation Guide

Complete guide for installing all required dependencies across different Linux distributions.

## Required Dependencies

### Core Dependencies (Required)
1. **Zig 0.16.0+** - Compiler
2. **PulseAudio development libraries** - Audio recording
3. **whisper.cpp** - Speech transcription (C library)

### Optional Dependencies (Platform-specific)
4. **xclip** (X11) or **wl-clipboard** (Wayland) - Clipboard access
5. **xdotool** - Text insertion

## Installation by Distribution

### Gentoo Linux

**All-in-one command:**
```bash
doas emerge -av x11-misc/xclip x11-misc/xdotool app-accessibility/whisper-cpp media-sound/pulseaudio
```

**Individual packages:**
```bash
# Core dependencies
doas emerge media-sound/pulseaudio           # Audio system
doas emerge app-accessibility/whisper-cpp    # Speech transcription (1.8.2)

# X11 tools
doas emerge x11-misc/xclip                   # Clipboard (0.13)
doas emerge x11-misc/xdotool                 # Text insertion (3.20211022.1-r1)

# Wayland alternative (if using Wayland)
doas emerge gui-apps/wl-clipboard            # Wayland clipboard
```

**Verify installation:**
```bash
pkg-config --modversion libpulse-simple      # Should show PulseAudio version
which whisper                                 # Should find /usr/bin/whisper
which xclip                                   # Should find /usr/bin/xclip
which xdotool                                 # Should find /usr/bin/xdotool
```

### Ubuntu / Debian

```bash
# Update package list
sudo apt update

# Core dependencies
sudo apt install libpulse-dev               # PulseAudio development libraries

# Clipboard and text insertion
sudo apt install xclip xdotool              # X11 tools
sudo apt install wl-clipboard               # Wayland alternative

# whisper.cpp (not in Ubuntu repos, build from source)
cd /tmp
git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp
make
sudo cp libwhisper.so /usr/local/lib/
sudo cp whisper.h /usr/local/include/
sudo ldconfig
```

### Arch Linux

```bash
# Core dependencies
sudo pacman -S pulseaudio                   # Audio system

# Clipboard and text insertion
sudo pacman -S xclip xdotool                # X11 tools
sudo pacman -S wl-clipboard                 # Wayland alternative

# whisper.cpp (in AUR)
yay -S whisper.cpp                          # From AUR
# OR build from source (same as Ubuntu)
```

### Fedora

```bash
# Core dependencies
sudo dnf install pulseaudio-libs-devel      # PulseAudio development libraries

# Clipboard and text insertion
sudo dnf install xclip xdotool              # X11 tools
sudo dnf install wl-clipboard               # Wayland alternative

# whisper.cpp (not in Fedora repos, build from source)
# Same process as Ubuntu above
```

### Alpine Linux

```bash
# Core dependencies
sudo apk add pulseaudio-dev                 # PulseAudio development libraries

# Clipboard and text insertion
sudo apk add xclip xdotool                  # X11 tools
sudo apk add wl-clipboard                   # Wayland alternative

# whisper.cpp (build from source)
# Same process as Ubuntu above
```

## Building whisper.cpp from Source

If your distribution doesn't package whisper.cpp (Ubuntu, Fedora, Alpine):

```bash
# Install build dependencies
sudo apt install build-essential git cmake  # Ubuntu/Debian
sudo dnf install gcc-c++ git cmake          # Fedora
sudo pacman -S base-devel git cmake         # Arch

# Clone and build
cd /tmp
git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp

# Build with CPU only (fastest to build)
make

# OR build with CUDA (NVIDIA GPU)
WHISPER_CUDA=1 make

# OR build with ROCm (AMD GPU)
WHISPER_HIPBLAS=1 make

# OR build with Vulkan (Universal GPU)
WHISPER_VULKAN=1 make

# Install system-wide
sudo cp libwhisper.so /usr/local/lib/
sudo cp whisper.h /usr/local/include/
sudo ldconfig

# Verify installation
ls -la /usr/local/lib/libwhisper.so
ls -la /usr/local/include/whisper.h
```

## Dependency Verification

Use the built-in dependency checker:

```bash
cd /home/fource/talkies/linux
./run.sh deps
```

**Expected output when all installed:**
```
✓ Zig 0.16.0-dev.1484+d0ba6642b found
ℹ Checking system dependencies...
✓ All dependencies installed
```

## Wayland vs X11 Detection

Talkies automatically detects your display server:

**X11 (default):** Uses xclip + xdotool
**Wayland:** Uses wl-clipboard + xdotool (via XWayland)

**Check your display server:**
```bash
echo $XDG_SESSION_TYPE  # Should be "x11" or "wayland"
```

## Optional: GPU Acceleration

For faster transcription on systems with GPUs:

### NVIDIA (CUDA)

**Gentoo:**
```bash
# Enable CUDA in whisper-cpp package
echo "app-accessibility/whisper-cpp cuda" >> /etc/portage/package.use/whisper
doas emerge --ask app-accessibility/whisper-cpp
```

**Other distributions:**
```bash
# Rebuild whisper.cpp with CUDA
cd /tmp/whisper.cpp
WHISPER_CUDA=1 make clean all
sudo cp libwhisper.so /usr/local/lib/
sudo ldconfig
```

### AMD (ROCm)

**Gentoo:**
```bash
# Enable ROCm in whisper-cpp package
echo "app-accessibility/whisper-cpp rocm" >> /etc/portage/package.use/whisper
doas emerge --ask app-accessibility/whisper-cpp
```

**Other distributions:**
```bash
# Install ROCm first (distro-specific)
# Then rebuild whisper.cpp with ROCm
cd /tmp/whisper.cpp
WHISPER_HIPBLAS=1 make clean all
sudo cp libwhisper.so /usr/local/lib/
sudo ldconfig
```

### Universal GPU (Vulkan)

**All distributions:**
```bash
# Install Vulkan SDK first
# Then rebuild whisper.cpp with Vulkan
cd /tmp/whisper.cpp
WHISPER_VULKAN=1 make clean all
sudo cp libwhisper.so /usr/local/lib/
sudo ldconfig
```

## Troubleshooting

### "pulse/simple.h: No such file or directory"

**Missing:** PulseAudio development libraries

**Fix:**
```bash
# Gentoo
doas emerge media-sound/pulseaudio

# Ubuntu/Debian
sudo apt install libpulse-dev

# Arch
sudo pacman -S pulseaudio

# Fedora
sudo dnf install pulseaudio-libs-devel
```

### "whisper.h: No such file or directory"

**Missing:** whisper.cpp library

**Fix:** Build and install whisper.cpp from source (see above)

### "xclip: command not found"

**Missing:** xclip (X11 clipboard tool)

**Fix:**
```bash
# Gentoo
doas emerge x11-misc/xclip

# Ubuntu/Debian
sudo apt install xclip

# Arch
sudo pacman -S xclip
```

### "wl-copy: command not found" (Wayland users)

**Missing:** wl-clipboard

**Fix:**
```bash
# Gentoo
doas emerge gui-apps/wl-clipboard

# Ubuntu/Debian
sudo apt install wl-clipboard

# Arch
sudo pacman -S wl-clipboard
```

### "xdotool: command not found"

**Missing:** xdotool

**Fix:**
```bash
# Gentoo
doas emerge x11-misc/xdotool

# Ubuntu/Debian
sudo apt install xdotool

# Arch
sudo pacman -S xdotool
```

## Minimum Versions

| Dependency | Minimum Version | Recommended |
|------------|----------------|-------------|
| Zig | 0.16.0 | Latest stable |
| PulseAudio | Any | Latest |
| whisper.cpp | 1.0.0 | 1.8.2+ |
| xclip | 0.12 | Latest |
| xdotool | 3.x | Latest |

## Size Requirements

| Component | Size |
|-----------|------|
| PulseAudio dev | ~5 MB |
| whisper.cpp (source) | ~7 MB |
| whisper.cpp (compiled) | ~3 MB |
| xclip | <1 MB |
| xdotool | <1 MB |
| **Total** | **~16 MB** |

## Next Steps

After installing dependencies:

1. **Build Talkies:**
   ```bash
   cd /home/fource/talkies/linux
   ./run.sh build
   ```

2. **Download whisper model:**
   ```bash
   ./run.sh models base
   ```

3. **Test audio:**
   ```bash
   ./run.sh audio
   ```

4. **Install system-wide:**
   ```bash
   ./run.sh install
   ```

See `docs/BUILD.md` for detailed build instructions.
