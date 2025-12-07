# Talkies Test Scripts

## Problem: Kokoro TTS Crashes

### Root Cause
Kokoro TTS requires MLX, which needs Metal shaders compiled into `default.metallib`.
Swift Package Manager **cannot** compile Metal shaders - this requires Xcode.

### Test Results

Run `test_mlx_simple.swift` to verify:
```bash
swift Tests/test_mlx_simple.swift
```

**Expected output:**
```
❌ No .metallib files found - this is the problem!
The Metal shader library (default.metallib) is missing.
```

### Solutions Implemented

✅ **Solution 1: Pre-flight Metal Library Check (IMPLEMENTED)**
   - App checks for `.metallib` files BEFORE attempting to load Kokoro TTS
   - If Metal library is missing, gracefully falls back to Native macOS TTS
   - Shows helpful error message explaining why Kokoro is unavailable
   - **No crashes!** App continues to work perfectly with Native TTS
   - No Xcode required

📋 **Solution 2: Install Xcode (For Kokoro TTS)**
   - Download Xcode from App Store
   - Convert project to Xcode project
   - Xcode will compile Metal shaders automatically
   - Then Kokoro TTS will work

## How It Works

### Metal Library Detection
The app now performs a pre-flight check in `MLXTTSPlugin.swift`:

1. **checkForMetalLibrary()** searches for `.metallib` files in:
   - `.build/arm64-apple-macosx/debug`
   - `.build/debug`
   - `.build/arm64-apple-macosx/release`
   - `.build/release`
   - `.build/checkouts/mlx-swift` (recursive search)

2. **If no .metallib found:**
   - Sets error status with helpful message
   - Automatically switches to Native TTS engine
   - User sees: "⚠️ Kokoro TTS unavailable: MLX Metal shaders require Xcode to compile."

3. **If .metallib found:**
   - Proceeds with Kokoro TTS initialization
   - Loads voice embeddings
   - Sets status to ready

### Code Location
See `Sources/Talkies/Plugins/MLXTTSPlugin.swift`:
- Line 136: `checkForMetalLibrary()` function
- Line 190: `loadKokoroTTS()` function with pre-flight check

## Test Scripts

### `test_mlx_simple.swift`
Checks if Metal libraries are available (they're not in SPM builds)

### `test_kokoro.swift`
Full Kokoro TTS initialization test (will fail without Xcode)

## Current Status

✅ **App launches** without crashes
✅ **Native TTS works** perfectly
✅ **Graceful degradation** when Kokoro unavailable
✅ **Helpful error messages** guide users
❌ **Kokoro TTS unavailable** (requires Xcode to compile Metal shaders)

## Testing the Fix

1. Build and launch the app:
   ```bash
   swift build && .build/debug/Talkies
   ```

2. App should launch successfully (no crash!)

3. Try switching to Kokoro TTS in settings:
   - Should see error message about Metal library
   - Should automatically fall back to Native TTS
   - App should NOT crash

4. Native TTS should work perfectly
