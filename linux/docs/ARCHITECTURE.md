# Talkies Linux - Architecture

## Design Philosophy

**Talkies Linux** is designed as a minimal, CLI-only application that implements the core workflow: **Record → Transcribe → Paste**. This document explains the architectural decisions and design patterns.

## Why Zig?

The Linux implementation was originally built with Rust + Tauri (GUI framework), but was completely rewritten in Zig for the following reasons:

| Consideration | Rust + Tauri | Zig |
|--------------|-------------|-----|
| **Build Speed** | 2-5 minutes | <10 seconds |
| **Binary Size** | 50-100 MB | <5 MB |
| **Complexity** | GUI + IPC + React | CLI only |
| **Dependencies** | 150+ crates | 1 (whisper.cpp) |
| **Code Volume** | ~5000 LOC | ~1,500 LOC |
| **Memory Control** | Automatic (borrow checker) | Manual (explicit allocators) |
| **C Interop** | Requires bindgen | Native via @cImport |

**Result:** Zig provides a cleaner, faster, more maintainable implementation for a CLI-focused tool.

## Module Architecture

### Layered Design

```
┌─────────────────────────────────────┐
│         main.zig (CLI)              │  ← User interface
├─────────────────────────────────────┤
│  audio.zig │ whisper.zig │ input.zig│  ← Core services
├─────────────────────────────────────┤
│     clipboard.zig │ config.zig      │  ← System integration
├─────────────────────────────────────┤
│         utils.zig (Logging)         │  ← Foundation
├─────────────────────────────────────┤
│  PulseAudio │ whisper.cpp │ xdotool │  ← External C libraries
└─────────────────────────────────────┘
```

### Module Responsibilities

#### 1. **main.zig** (CLI Interface)
- **Purpose:** Command routing and orchestration
- **Pattern:** Simple command dispatcher
- **Commands:** quick, record, models, config, audio, help
- **Design Choice:** No complex CLI framework needed - simple string matching suffices

**Key Function:**
```zig
pub fn main() !void {
    const command = parseCommand(args[1]);
    switch (command) {
        .quick => try runQuick(allocator),
        .record => try runRecord(allocator),
        // ...
    }
}
```

#### 2. **audio.zig** (PulseAudio Recording)
- **Purpose:** Record 16kHz mono PCM audio to WAV files
- **Pattern:** C FFI with Zig wrapper
- **External API:** PulseAudio Simple API (pa_simple_*)
- **Design Choice:** Simple API over Asynchronous API (no GUI to update)

**WAV Format:**
```
RIFF Header (12 bytes)
  ├─ "RIFF" magic
  ├─ File size - 8
  └─ "WAVE" format
fmt Chunk (24 bytes)
  ├─ PCM format = 1
  ├─ Channels = 1 (mono)
  ├─ Sample rate = 16000 Hz
  └─ Bits per sample = 16
data Chunk (8 + N bytes)
  ├─ "data" magic
  ├─ Data size
  └─ PCM samples
```

**Key Innovation:** Real-time RMS calculation for visual feedback without GUI

#### 3. **whisper.zig** (Speech Transcription)
- **Purpose:** C FFI to whisper.cpp library
- **Pattern:** Opaque pointer wrapping with Zig safety
- **External API:** whisper.cpp C API
- **Design Choice:** Use existing C library rather than reimplement in Zig

**C FFI Approach:**
```zig
const c = @cImport({
    @cInclude("whisper.h");
});

pub const WhisperService = struct {
    ctx: ?*c.whisper_context = null,

    pub fn loadModel(self: *WhisperService, name: []const u8) !void {
        self.ctx = c.whisper_init_from_file_with_params(...);
    }
};
```

**Memory Management:**
- Whisper context owned by WhisperService
- Automatic cleanup via deinit()
- Transcribed text returned as owned string (caller frees)

#### 4. **clipboard.zig** (X11/Wayland Clipboard)
- **Purpose:** Cross-platform clipboard access
- **Pattern:** Strategy pattern (X11 vs Wayland)
- **External Tools:** xclip (X11), wl-copy/wl-paste (Wayland)
- **Design Choice:** Shell out to tools rather than use low-level X11/Wayland protocols

**Detection Logic:**
```zig
fn detectWayland() bool {
    return std.posix.getenv("WAYLAND_DISPLAY") != null or
           std.mem.eql(u8, std.posix.getenv("XDG_SESSION_TYPE") orelse "", "wayland");
}
```

**Why subprocess instead of native protocols?**
- X11 clipboard protocol is complex (requires X11 event loop)
- Wayland protocol requires compositor-specific extensions
- xclip/wl-clipboard are universally available and maintained
- CLI tool doesn't need clipboard event monitoring

#### 5. **input.zig** (Text Insertion)
- **Purpose:** Simulate keyboard input to paste text
- **Pattern:** Clipboard save/restore (inspired by macOS implementation)
- **External Tool:** xdotool
- **Design Choice:** Paste method over direct typing (faster, preserves formatting)

**Workflow:**
```zig
pub fn insertTextAtCursor(self: *TextInserter, text: []const u8) !void {
    const original = try self.clipboard.get();    // Save clipboard
    defer self.allocator.free(original);

    try self.clipboard.copy(text);                // Copy new text
    std.time.sleep(50_000_000);                   // 50ms delay
    try self.paste();                             // Simulate Ctrl+V
    std.time.sleep(200_000_000);                  // 200ms delay
    try self.clipboard.copy(original);            // Restore clipboard
}
```

**Why delays?**
- 50ms pre-paste: Ensure clipboard is updated in compositor
- 200ms pre-restore: Allow target app to read clipboard

#### 6. **config.zig** (Configuration Management)
- **Purpose:** TOML config file management
- **Pattern:** Struct serialization with XDG compliance
- **No External Library:** Custom minimal TOML parser
- **Design Choice:** Avoid heavyweight TOML library for 5 config keys

**XDG Base Directory Support:**
```zig
pub fn getConfigDir(allocator: std.mem.Allocator) ![]const u8 {
    const xdg = std.posix.getenv("XDG_CONFIG_HOME");
    if (xdg) |config_base| {
        return std.fmt.allocPrint(allocator, "{s}/talkies", .{config_base});
    } else {
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
        return std.fmt.allocPrint(allocator, "{s}/.config/talkies", .{home});
    }
}
```

**Custom TOML Parser:**
- Only supports sections `[name]`, key=value, strings, bools, integers
- No arrays, tables, or advanced features (not needed)
- ~150 LOC vs ~5000 LOC for full TOML library

#### 7. **utils.zig** (Foundation Layer)
- **Purpose:** Common utilities and logging
- **Pattern:** Pure functions with no state
- **Design Choice:** Simple debug printing over complex logging framework

**Logging Approach:**
```zig
pub fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[talkies] " ++ fmt ++ "\n", args);
}
```

**Why std.debug.print?**
- Unbuffered (immediate output)
- Works on all platforms
- No configuration needed
- Automatically goes to stderr (correct for logging)

## Memory Management Strategy

### Allocator Choice

**General Purpose Allocator (GPA)** used in main:
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();
```

**Why GPA over ArenaAllocator?**
- Long-running CLI commands (recording sessions)
- Need to free individual allocations (WAV buffers)
- Memory leak detection in debug builds

### Ownership Rules

1. **Return Values:** Caller owns and must free
   ```zig
   pub fn transcribe(self: *WhisperService, path: []const u8) ![]const u8 {
       return try self.allocator.dupe(u8, result); // Caller frees
   }
   ```

2. **Config Strings:** Service owns, freed in deinit()
   ```zig
   pub fn deinit(self: *Config) void {
       if (self.model_owned) self.allocator.free(self.model);
   }
   ```

3. **Temporary Buffers:** Freed immediately with defer
   ```zig
   const temp = try allocator.alloc(u8, 1024);
   defer allocator.free(temp);
   ```

## Error Handling

### Error Sets

Each module defines specific errors:
```zig
// audio.zig
pub const AudioError = error{
    PulseAudioInitFailed,
    RecordingFailed,
    FileWriteFailed,
};

// whisper.zig
pub const WhisperError = error{
    WhisperInitFailed,
    TranscriptionFailed,
    ModelNotFound,
};
```

### Error Propagation

**Pattern:** Try-catch at CLI level only
```zig
// In module: propagate errors upward
pub fn transcribe(...) ![]const u8 {
    if (ctx == null) return error.WhisperInitFailed;
}

// In main.zig: catch and display user-friendly messages
fn runQuick(allocator: std.mem.Allocator) !void {
    whisper.transcribe(path) catch |err| {
        utils.logError("Transcription failed: {}", .{err});
        return;
    };
}
```

## Testing Strategy

### Unit Tests

Each module includes inline tests:
```zig
test "audio recorder initialization" {
    const allocator = std.testing.allocator;
    var recorder = AudioRecorder.init(allocator);
    defer recorder.deinit();

    try std.testing.expect(recorder.sample_rate == 16000);
}
```

**Run with:** `zig build test`

### Integration Tests

Manual testing commands:
```bash
# Test audio recording
talkies audio

# Test config load/save
talkies config
cat ~/.config/talkies/config.toml

# Test model download
talkies models
ls ~/.local/share/talkies/models/
```

### Why No Mocking Framework?

- Zig philosophy: prefer integration tests
- Real hardware testing is more valuable
- Mock frameworks add complexity without clear benefit
- C FFI difficult to mock (would need wrapper layer)

## Performance Characteristics

### Build Performance

| Operation | Time | Reason |
|-----------|------|--------|
| Clean build (debug) | <5s | Minimal dependencies, incremental compilation |
| Incremental build | <1s | Zig's cache-aware build system |
| Clean build (release) | <10s | LTO and optimizations |

### Runtime Performance

| Operation | Time | Bottleneck |
|-----------|------|------------|
| CLI startup | <10ms | No GUI framework loading |
| Audio recording | Real-time | PulseAudio buffering (4KB chunks) |
| Whisper transcription | ~0.5s per second of audio (CPU-dependent) | whisper.cpp computation |
| Clipboard copy | <5ms | Subprocess spawn overhead |
| Text paste | <100ms | xdotool + compositor delay |

## Platform-Specific Considerations

### X11 vs Wayland

**Detection:**
```zig
const is_wayland = std.posix.getenv("WAYLAND_DISPLAY") != null;
```

**Clipboard Differences:**
- X11: Clipboard survives app termination (handled by X server)
- Wayland: Clipboard dies with app (need wl-clipboard daemon)

**Text Insertion:**
- X11: xdotool works natively
- Wayland: xdotool works via XWayland (may have focus issues)

### Audio Stack

**PulseAudio** chosen over ALSA/PipeWire:
- PulseAudio: Most compatible (works everywhere)
- ALSA: Too low-level (complex device management)
- PipeWire: Not universally available yet (Fedora/Ubuntu only)

**Future:** Detect PipeWire and use native API when available

## Comparison with Platform Implementations

### Windows (C# WPF)

| Feature | Windows | Linux (Zig) |
|---------|---------|-------------|
| Audio API | WASAPI | PulseAudio |
| Transcription | Whisper.net | whisper.cpp (C FFI) |
| Clipboard | Win32 API | xclip/wl-clipboard |
| Text Insertion | SendInput() | xdotool |
| Config | JSON | TOML |
| UI | WPF GUI | CLI |

**Code Similarity:** High (same workflow, similar structure)

### macOS (Swift)

| Feature | macOS | Linux (Zig) |
|---------|-------|-------------|
| Audio API | AVFoundation | PulseAudio |
| Transcription | WhisperKit | whisper.cpp |
| Clipboard | NSPasteboard | xclip/wl-clipboard |
| Text Insertion | CGEvent | xdotool |
| Config | UserDefaults | TOML |
| UI | SwiftUI | CLI |

**Code Similarity:** Medium (different language, but same patterns)

## Future Enhancements

### Planned Features

1. **Global Hotkeys** - Use evdev to listen for key combinations
2. **System Tray** - Optional GUI status indicator (via libappindicator)
3. **GPU Acceleration** - Detect CUDA/ROCm and use GPU-accelerated whisper
4. **PipeWire Native** - Detect and use PipeWire API when available
5. **DBus Integration** - Expose API for other apps to trigger recording

### Architecture Evolution

**Current:** CLI-only monolith
**Future:** Daemon + CLI client architecture
```
talkies-daemon  (background process, global hotkeys)
     ↕
talkies         (CLI client, sends commands via socket)
```

**Benefits:**
- Global hotkeys work without terminal
- Persistent configuration
- Better resource management

## References

- [Zig Language Documentation](https://ziglang.org/documentation/master/)
- [PulseAudio Simple API](https://freedesktop.org/software/pulseaudio/doxygen/simple.html)
- [whisper.cpp C API](https://github.com/ggml-org/whisper.cpp/blob/master/include/whisper.h)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)
