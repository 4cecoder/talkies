#!/bin/bash
# Talkies Full Workflow Test Script

set -e

echo "=== Talkies Linux Workflow Test ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Clean up
print_step "1. Cleaning up any stuck processes..."
zig build cleanup || print_error "Cleanup failed (non-critical)"
echo ""

# Step 2: Build
print_step "2. Building talkies..."
zig build || { print_error "Build failed!"; exit 1; }
echo ""

# Step 3: Check config
print_step "3. Checking configuration..."
CONFIG_FILE="$HOME/.config/talkies/config.toml"
if [ -f "$CONFIG_FILE" ]; then
    print_info "Config file exists: $CONFIG_FILE"
    AUDIO_DEVICE=$(grep -E '^device\s*=' "$CONFIG_FILE" | cut -d'"' -f2)
    print_info "Audio device: ${AUDIO_DEVICE:-default}"
else
    print_error "Config file not found!"
    exit 1
fi
echo ""

# Step 4: Check audio device
print_step "4. Verifying audio device..."
if pactl list sources short | grep -q "$AUDIO_DEVICE"; then
    print_info "Audio device is available"
else
    print_error "Audio device not found in PulseAudio/PipeWire!"
    print_info "Available sources:"
    pactl list sources short
    exit 1
fi
echo ""

# Step 5: Check toggle script
print_step "5. Checking toggle script..."
TOGGLE_SCRIPT="$HOME/.config/hypr/scripts/talkies-toggle.sh"
if [ -f "$TOGGLE_SCRIPT" ]; then
    print_info "Toggle script exists"
    if [ -x "$TOGGLE_SCRIPT" ]; then
        print_info "Toggle script is executable"
    else
        print_error "Toggle script is not executable!"
        print_info "Run: chmod +x $TOGGLE_SCRIPT"
    fi
else
    print_error "Toggle script not found at $TOGGLE_SCRIPT"
fi
echo ""

# Step 6: Test parecord
print_step "6. Testing parecord (2 second recording)..."
TEST_FILE="/tmp/talkies-test-parecord.wav"
rm -f "$TEST_FILE"
print_info "Recording 2 seconds of audio..."
timeout 2 parecord --device="$AUDIO_DEVICE" --format=s16le --rate=16000 --channels=1 "$TEST_FILE" >/dev/null 2>&1 || true
if [ -f "$TEST_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$TEST_FILE")
    if [ "$FILE_SIZE" -gt 10000 ]; then
        print_info "Recording successful! File size: ${FILE_SIZE} bytes"
    else
        print_error "Recording file too small: ${FILE_SIZE} bytes"
    fi
    rm -f "$TEST_FILE"
else
    print_error "Recording failed!"
fi
echo ""

# Step 7: Instructions
print_step "7. Manual test instructions"
echo ""
echo "Now you need to manually test the daemon:"
echo ""
echo "  Terminal 1 (daemon):"
echo "    cd ~/talkies/linux"
echo "    zig build run -- daemon"
echo ""
echo "  Terminal 2 (overlay - optional):"
echo "    cd ~/talkies/linux"
echo "    zig build overlay"
echo ""
echo "  Then press Super+Alt+T to toggle recording"
echo "  Speak for 3-5 seconds, then press Super+Alt+T again"
echo ""
echo "Expected output in daemon terminal:"
echo "  - WebSocket: Received start_recording command"
echo "  - State changed: recording"
echo "  - WebSocket: Received stop_recording command"
echo "  - State changed: processing"
echo "  - [DEBUG] Waiting for recording file to be written..."
echo "  - 📝 Transcription (N chars): <your text here>"
echo "  - ✨ Inserting text at cursor..."
echo "  - ✅ Done!"
echo ""
echo "Expected behavior in overlay (if running):"
echo "  - Window appears when recording starts"
echo "  - Shows red dot and 'Recording'"
echo "  - Shows 'Processing' when transcribing"
echo "  - Hides when done"
echo ""

print_step "All pre-flight checks complete!"
