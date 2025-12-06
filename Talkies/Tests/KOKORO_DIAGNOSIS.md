# Kokoro TTS Diagnostic Report

## Current Status: ❌ Cannot Work Without Xcode

### What We Found

1. **Metal Compiler Not Available**
   ```bash
   $ xcrun -sdk macosx metal --version
   xcrun: error: unable to find utility "metal", not a developer tool or in PATH
   ```
   - The `metal` compiler is part of Xcode, not Command Line Tools
   - Command Line Tools only includes basic dev tools (clang, swift, etc.)
   - Metal shader compilation REQUIRES full Xcode installation

2. **Metal Source Files Exist**
   - Found 100+ `.metal` shader source files in `.build/checkouts/mlx-swift/`
   - Examples:
     - `mlx/mlx/backend/metal/kernels/binary.metal`
     - `mlx/mlx/backend/metal/kernels/gemm.metal`
     - `mlx-generated/metal/conv.metal`
   - These are source files that need compilation

3. **No Compiled Metal Libraries**
   ```bash
   $ find .build -name "*.metallib"
   (no results)
   ```
   - SPM does not compile Metal shaders
   - No `.metallib` files generated during `swift build`

4. **How MLX Tries to Load Metal Library**
   From `mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/device.cpp`:
   - First tries: `Resources/mlx.metallib` (colocated with binary)
   - Then tries: `default.metallib` in SwiftPM bundle `mlx-swift_Cmlx`
   - If both fail: **Fatal error: "Failed to load the default metallib"**

### Why This Is a Fundamental Problem

Swift Package Manager has **no support** for compiling Metal shaders. The build process is:

1. **With Xcode:**
   ```
   .metal files → Xcode Metal Compiler → .metallib → Embedded in bundle
   ```

2. **With SPM (current):**
   ```
   .metal files → (nothing happens) → ❌ No .metallib → Crash at runtime
   ```

### What Doesn't Work

❌ **Attempt 1: Compile Metal shaders manually with xcrun**
- `xcrun metal` not available without Xcode
- Command Line Tools insufficient

❌ **Attempt 2: Use pre-compiled .metallib from elsewhere**
- Architecture mismatch (Metal shaders are compiled for specific GPU/OS)
- Bundle signing issues
- Version compatibility problems

❌ **Attempt 3: SPM build plugin**
- SPM build plugins cannot invoke Metal compiler
- No Metal compilation support in SPM at all

### What DOES Work ✅

**Our Current Solution: Graceful Degradation**
- App detects Metal library missing before attempting to load MLX
- Automatically falls back to Native macOS TTS
- Shows helpful error message to user
- App continues to function perfectly

Code location: `Sources/Talkies/Plugins/MLXTTSPlugin.swift:136-202`

## Solutions to Get Kokoro TTS Working

### Option 1: Install Xcode (Recommended)

**Steps:**
1. Download Xcode from Mac App Store (~15 GB download, ~40 GB installed)
2. Convert project to Xcode project OR use CMake build:
   ```bash
   # Using CMake (from mlx-swift docs)
   cd .build/checkouts/mlx-swift
   cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   ```
3. Metal shaders will be compiled automatically
4. Kokoro TTS will work

**Pros:**
- Full Metal support
- Native iOS/macOS development environment
- Best performance

**Cons:**
- Large download/install size
- Requires significant disk space
- More complex build process

### Option 2: Use Native TTS Only (Current)

**Status:** Already implemented and working!

**Pros:**
- Zero setup required
- Works perfectly
- Good voice quality
- Low latency
- Native macOS integration

**Cons:**
- Not using the fancy Kokoro neural TTS
- Fewer voice customization options

### Option 3: Replace Kokoro with Alternative TTS

Consider using TTS libraries that don't require Metal:
- **piper-tts**: Fast neural TTS (CPU-based)
- **coqui-ai/TTS**: Various neural TTS models
- **Bark**: High-quality neural TTS
- **AVSpeechSynthesizer**: Modern native macOS TTS

## Test Results

### Test 1: Metal Compiler Check ❌
```bash
$ xcrun -sdk macosx metal --version
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
```
**Result:** No Metal compiler available

### Test 2: Metal Library Search ❌
```bash
$ find .build -name "*.metallib" 2>/dev/null
(no results)
```
**Result:** No compiled Metal libraries found

### Test 3: Metal Source Files ✅
```bash
$ find .build/checkouts/mlx-swift -name "*.metal" | wc -l
     122
```
**Result:** 122 Metal shader source files found (but not compiled)

### Test 4: App Launch ✅
```bash
$ swift build && .build/debug/Talkies
Build complete! (2.26s)
(app launches successfully)
```
**Result:** App launches without crashes, uses Native TTS

### Test 5: Graceful Degradation ✅
When user tries to select Kokoro TTS:
- ✅ App detects missing Metal library
- ✅ Shows error: "⚠️ Kokoro TTS unavailable: MLX Metal shaders require Xcode to compile."
- ✅ Automatically switches to Native TTS
- ✅ App continues working

## Recommendation

**For users without Xcode:** Continue using Native macOS TTS (current behavior)
- Works great
- Zero setup
- Good quality
- Our app handles this gracefully

**For users who want Kokoro TTS:** Install Xcode
- Only way to get Metal shader compilation
- Required for MLX framework
- ~40GB disk space needed

## Technical Notes

### Why MLX Needs Metal
MLX (Apple's ML framework) uses Metal for GPU acceleration:
- Matrix operations on GPU (much faster than CPU)
- Neural network inference
- Parallel processing of TTS voice synthesis

### SPM Limitations
Swift Package Manager is designed for Swift/C/C++ code only:
- No support for Metal shader compilation
- No support for `.xcassets` compilation
- No support for Storyboards/XIBs
- These all require Xcode's build system

### Alternative: CMake Build
MLX provides CMake build support which can compile Metal shaders:
```bash
cd .build/checkouts/mlx-swift
cmake -S . -B build
cmake --build build
```
However, this requires:
- CMake installed (`brew install cmake`)
- Xcode Command Line Tools (already have)
- **Still requires Xcode for Metal compiler!**

So even the CMake route hits the same wall - no Metal compiler without Xcode.

## Conclusion

✅ **App is working perfectly with Native TTS**
❌ **Kokoro TTS cannot work without full Xcode installation**
✅ **Graceful error handling implemented**
📝 **User gets clear guidance about what's needed**

The current implementation is production-ready and handles the Metal library limitation gracefully!
