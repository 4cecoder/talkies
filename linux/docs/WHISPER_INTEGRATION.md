# Whisper.cpp C FFI Integration

This document describes the whisper.cpp C FFI integration for Talkies Linux (Zig implementation).

## Overview

The `src/whisper.zig` module provides a Zig wrapper around the whisper.cpp C library for on-device speech transcription. The implementation uses C FFI via `@cImport` to interface with whisper.cpp's C API.

## Architecture

### C FFI Bindings

The module uses Zig's `@cImport` to import whisper.cpp C headers:

```zig
const c = @cImport({
    @cInclude("whisper.h");
});
```

Key C functions used:
- `whisper_context_default_params()` - Get default context parameters
- `whisper_init_from_file_with_params()` - Initialize model from disk
- `whisper_full_default_params()` - Get default transcription parameters
- `whisper_full()` - Run transcription on audio samples
- `whisper_full_n_segments()` - Get number of transcription segments
- `whisper_full_get_segment_text()` - Get text for a segment
- `whisper_full_get_segment_t0()` - Get segment start time (centiseconds)
- `whisper_full_get_segment_t1()` - Get segment end time (centiseconds)
- `whisper_free()` - Free whisper context

### WhisperService API

#### Initialization

```zig
var service = WhisperService.init(allocator);
defer service.deinit();
```

#### Model Management

**Load a model from disk:**
```zig
try service.loadModel("base"); // Loads from ~/.local/share/talkies/models/ggml-base.bin
```

**Download a model from Hugging Face:**
```zig
try service.downloadModel("base"); // Downloads ggml-base.bin if not present
```

Supported models:
- `tiny` - Fastest, lowest accuracy (~75 MB)
- `base` - Balanced speed/accuracy (~142 MB)
- `small` - Better accuracy (~466 MB)
- `medium` - High accuracy (~1.5 GB)
- `large` - Best accuracy (~2.9 GB)

All models downloaded from: https://huggingface.co/ggerganov/whisper.cpp

#### Transcription

**Simple transcription (text only):**
```zig
const text = try service.transcribe("audio.wav");
defer allocator.free(text);
```

**Transcription with segments (includes timing):**
```zig
const segments = try service.getSegments();
defer service.freeSegments(segments);

for (segments) |seg| {
    std.debug.print("[{d:.2}s - {d:.2}s]: {s}\n", .{seg.start, seg.end, seg.text});
}
```

## Implementation Details

### Model Storage

Models are stored in `~/.local/share/talkies/models/` following the XDG Base Directory Specification.

Path structure:
```
~/.local/share/talkies/
└── models/
    ├── ggml-tiny.bin
    ├── ggml-base.bin
    ├── ggml-small.bin
    ├── ggml-medium.bin
    └── ggml-large.bin
```

### Audio Format Requirements

The current implementation expects WAV files with:
- **Sample Rate**: 16 kHz
- **Channels**: Mono (1 channel)
- **Format**: PCM 16-bit signed integer

The `readAudioFile()` function:
1. Skips the standard 44-byte WAV header
2. Reads int16 PCM samples
3. Converts to float32 normalized to [-1.0, 1.0] range

For production use, consider adding:
- Proper WAV header parsing
- Format validation
- Automatic resampling for non-16kHz audio
- Multi-channel to mono conversion

### HTTP Model Download

Model downloads use Zig's `std.http.Client` with:
- Chunked reading (8 KB buffer)
- Progress logging every 1 MB
- Automatic directory creation
- Skip download if model already exists

### Memory Management

- Model path strings are allocated and freed by the service
- The whisper context (`ctx`) is freed on `deinit()` or when loading a new model
- Transcription text is allocated and must be freed by caller
- Segment slices must be freed with `freeSegments()`

## Build Configuration

### System Requirements

**Option 1: Use whisper.cpp as header-only (current approach)**

The current implementation uses C FFI bindings via `@cImport` but doesn't link against whisper.cpp. This means:
- The code compiles without whisper.cpp installed
- At runtime, you'll need whisper.cpp compiled and linked
- Suitable for development/prototyping

**Option 2: Link against system whisper.cpp library**

Add to `build.zig`:
```zig
exe.linkSystemLibrary("whisper");
exe.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
```

**Option 3: Build whisper.cpp from source**

Clone and build whisper.cpp:
```bash
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp
make libwhisper.a
```

Then link in `build.zig`:
```zig
exe.addIncludePath(.{ .cwd_relative = "../whisper.cpp" });
exe.addObjectFile(.{ .cwd_relative = "../whisper.cpp/libwhisper.a" });
```

## Testing

The module includes unit tests:

```bash
zig build test
```

Current tests:
1. **Service initialization** - Verifies clean initialization state
2. **Model path construction** - Tests model URL mapping

For full integration testing, you'll need:
- A compiled whisper.cpp library
- Sample WAV files (16kHz mono PCM)
- Downloaded GGML models

## Limitations & Future Work

### Current Limitations

1. **No whisper.cpp linking**: Code compiles but won't run without linking whisper.cpp
2. **Simple WAV parsing**: Assumes standard 44-byte header, no validation
3. **No audio preprocessing**: Requires pre-converted 16kHz mono PCM
4. **No GPU support**: Uses CPU-only transcription
5. **No progress callbacks**: Downloads/transcription have no real-time progress

### Future Enhancements

1. **Complete whisper.cpp integration**:
   - Add whisper.cpp as a vendored dependency or system library
   - Implement proper build.zig configuration for linking

2. **Audio preprocessing**:
   - Proper WAV header parsing with validation
   - Automatic resampling (any rate → 16 kHz)
   - Multi-channel to mono conversion
   - Support additional formats (MP3, FLAC, Opus)

3. **GPU acceleration**:
   - Detect CUDA/ROCm/Vulkan availability
   - Set appropriate environment variables
   - Use GPU-optimized model variants

4. **Progress reporting**:
   - Callback function for download progress
   - Transcription progress estimation
   - Segment-by-segment streaming results

5. **Language & parameters**:
   - Language detection and selection
   - Temperature/beam search tuning
   - VAD (Voice Activity Detection) configuration
   - Custom prompts for context

6. **Export formats**:
   - VTT (WebVTT) subtitle generation
   - SRT (SubRip) subtitle generation
   - JSON structured output

## Reference Implementation

See the Windows C# implementation for comparison:
- `/home/fource/talkies/windows/Talkies.Windows/Services/WhisperNetTranscriptionService.cs`

The Zig implementation mirrors the Windows approach:
- Same Hugging Face model URLs
- Similar transcription workflow
- Equivalent segment processing
- Parallel feature set (download, load, transcribe)

## Resources

- [whisper.cpp GitHub](https://github.com/ggml-org/whisper.cpp)
- [whisper.cpp C API header](https://github.com/ggml-org/whisper.cpp/blob/master/include/whisper.h)
- [Hugging Face GGML models](https://huggingface.co/ggerganov/whisper.cpp)
- [OpenAI Whisper paper](https://arxiv.org/abs/2212.04356)
