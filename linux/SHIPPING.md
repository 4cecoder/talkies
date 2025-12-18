# Shipping Talkies Linux

Quick reference for building and distributing Talkies Linux across different platforms.

## Dependencies Summary

### Runtime Dependencies (Required)
1. **PulseAudio** - Audio system (pre-installed on most distros)
2. **whisper-cpp 1.8.2+** - Speech transcription library
3. **xclip** (X11) or **wl-clipboard** (Wayland) - Clipboard access
4. **xdotool** - Text insertion

### Build Dependencies
1. **Zig 0.16.0+** - Compiler

## Quick Install by Distribution

### Gentoo (BEST SUPPORT - All in repos!)
```bash
doas emerge -av media-sound/pulseaudio \\
                app-accessibility/whisper-cpp \\
                x11-misc/xclip \\
                x11-misc/xdotool

cd linux && zig build
```

### Ubuntu/Debian
```bash
sudo apt install libpulse-dev xclip xdotool

# whisper.cpp not in repos - build from source
git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp && make
sudo cp libwhisper.so /usr/local/lib/
sudo cp whisper.h /usr/local/include/
sudo ldconfig
```

### Arch Linux
```bash
sudo pacman -S pulseaudio xclip xdotool
yay -S whisper.cpp  # From AUR
```

### Fedora
```bash
sudo dnf install pulseaudio-libs-devel xclip xdotool

# whisper.cpp - build from source (same as Ubuntu)
```

## Build Process

```bash
# Clone repository
git clone https://github.com/4cecoder/talkies
cd talkies/linux

# Check dependencies
./run.sh deps

# Build
./run.sh build

# Test
./run.sh test

# Install system-wide
./run.sh install
```

## Distribution-Specific Packaging

### Gentoo Ebuild
whisper-cpp is already in GURU overlay at `app-accessibility/whisper-cpp-1.8.2`

**Recommended ebuild dependencies:**
```ebuild
DEPEND="
    >=dev-lang/zig-0.16.0
    media-sound/pulseaudio
    app-accessibility/whisper-cpp
    x11-misc/xclip
    x11-misc/xdotool
"
```

### Debian Package
```bash
# Build dependencies
Build-Depends: zig (>= 0.16.0), libpulse-dev

# Runtime dependencies
Depends: pulseaudio, xclip, xdotool, libwhisper1
```

### Arch PKGBUILD
```bash
depends=('pulseaudio' 'whisper.cpp' 'xclip' 'xdotool')
makedepends=('zig>=0.16.0')
```

## Binary Distribution

### Static Binary (Future)
For maximum portability, consider statically linking whisper.cpp:

```bash
# Build static whisper.cpp
cd /tmp
git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp
make libwhisper.a

# Update build.zig to link statically
# (requires vendoring or submodule approach)
```

### AppImage (Future)
Bundle all dependencies in AppImage for universal Linux support.

### Flatpak (Future)
Flatpak manifest with all dependencies bundled.

## Size Breakdown

| Component | Size | Notes |
|-----------|------|-------|
| talkies binary (debug) | 9.1 MB | Includes debug symbols |
| talkies binary (release) | ~2 MB | Optimized, stripped |
| libwhisper.so | ~3 MB | System library |
| PulseAudio libs | ~5 MB | Usually pre-installed |
| xclip | <1 MB | Tiny utility |
| xdotool | <1 MB | Tiny utility |
| **Total (new install)** | **~11 MB** | Excluding PulseAudio |

## Whisper Models

Models are downloaded on first use to `~/.local/share/talkies/models/`

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| tiny | 75 MB | Very Fast | Low |
| base | 150 MB | Fast | Medium |
| small | 500 MB | Medium | Good |
| medium | 1.5 GB | Slow | Very Good |
| large | 3 GB | Very Slow | Best |

**Recommendation:** Ship without models, download on first run.

## Current Status

✅ **Ready to Ship:**
- Complete source code (1,509 LOC)
- Build system working
- All dependencies documented
- Tests passing
- Cross-distro instructions

⚠️ **Not Yet Ready:**
- Main workflow still has stubs (needs integration)
- No binary releases yet
- No package manager submissions

## Next Steps for Production

1. **Wire up main.zig** - Integrate modules for working app
2. **Create release builds** - Optimize and strip binaries
3. **Submit to package repos:**
   - Gentoo GURU overlay (ebuild)
   - AUR for Arch
   - Debian PPA
   - Fedora COPR
4. **CI/CD** - Automated builds and tests
5. **Binary releases** - GitHub releases with artifacts

## Support Matrix

| Distribution | Support Level | Notes |
|--------------|---------------|-------|
| Gentoo | ✅ Full | All deps in repos! |
| Arch | ✅ Full | whisper.cpp in AUR |
| Ubuntu 22.04+ | ⚠️ Partial | Need to build whisper.cpp |
| Debian 12+ | ⚠️ Partial | Need to build whisper.cpp |
| Fedora 38+ | ⚠️ Partial | Need to build whisper.cpp |
| Alpine | ⚠️ Partial | Need to build whisper.cpp |

## Troubleshooting

See `docs/DEPENDENCIES.md` for detailed troubleshooting.

**Common issues:**
- Missing whisper.h → Install whisper-cpp or build from source
- Missing pulse/simple.h → Install libpulse-dev
- xclip not found → Install xclip package
- Build takes long time → Normal, whisper.cpp is large

## Documentation

- `docs/README.md` - User guide
- `docs/BUILD.md` - Detailed build instructions
- `docs/DEPENDENCIES.md` - Dependency installation
- `docs/ARCHITECTURE.md` - Technical design
- `WHISPER_INTEGRATION.md` - C FFI details

## License

See root LICENSE file for details.
