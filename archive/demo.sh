#!/bin/bash
# Talkies v0.2.0 - Real-Time VTT Demo Script

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎤 Talkies v0.2.0 - Real-Time VTT"
echo "  Blazing-fast transcription optimized for Apple Silicon M4"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Warning: This demo is optimized for macOS (M4 Pro)"
    echo "   It will still work, but without Metal GPU acceleration"
    echo ""
fi

# Menu
echo "Choose a demo:"
echo ""
echo "  1. 💻 Real-Time VTT (Recommended)"
echo "  2. ⚡ Quick Test (5 seconds)"
echo "  3. 🎯 Professional Mode (medium model)"
echo "  4. 📊 List Available Models"
echo "  5. 🎤 List Audio Devices"
echo "  6. ℹ️  System Info"
echo ""
read -p "Select option (1-6): " choice

case $choice in
    1)
        echo ""
        echo "💻 Starting real-time VTT..."
        echo "   - Transcription will appear in real-time"
        echo "   - Press Ctrl+C to stop"
        echo ""
        ./run.sh live --model base --language en
        ;;
    2)
        echo ""
        echo "⚡ Quick 5-second test..."
        echo "   - Recording for 5 seconds"
        echo "   - Say something!"
        echo ""
        ./run.sh live --model tiny --duration 5 --output test_output.vtt

        if [ -f "test_output.vtt" ]; then
            echo ""
            echo "✅ Test complete! Output saved to test_output.vtt"
            echo ""
            echo "━━━ VTT Content ━━━"
            cat test_output.vtt
            echo "━━━━━━━━━━━━━━━━━━"
        fi
        ;;
    3)
        echo ""
        echo "🎯 Professional mode (medium model)..."
        echo "   - Higher accuracy"
        echo "   - Still real-time on M4!"
        echo "   - Press Ctrl+C to stop"
        echo ""
        ./run.sh live --model medium --language en --output professional.vtt
        ;;
    4)
        echo ""
        echo "📊 Available Whisper Models:"
        echo ""
        echo "  Model    | Speed        | Accuracy | Memory  | Recommended For"
        echo "  ---------|--------------|----------|---------|------------------"
        echo "  tiny     | Blazing fast | Good     | ~75 MB  | Quick tests"
        echo "  base     | Very fast    | Better   | ~140 MB | Default (best balance)"
        echo "  small    | Fast         | Great    | ~460 MB | Meetings"
        echo "  medium   | Moderate     | Excellent| ~1.5 GB | Professional"
        echo "  large    | Slower       | Best     | ~2.9 GB | Critical work"
        echo ""
        echo "On M4 Pro: Even 'medium' runs in real-time! 🚀"
        echo ""
        ;;
    5)
        echo ""
        echo "🎤 Available Audio Devices:"
        echo ""
        ./run.sh record --list-devices
        ;;
    6)
        echo ""
        echo "ℹ️  System Information:"
        echo ""
        ./run.sh system
        echo ""
        echo "Checking M4 optimization..."
        python3 -c "
try:
    import mlx
    print('✅ MLX available - M4 GPU acceleration enabled')
except ImportError:
    print('⚠️  MLX not available - using CPU fallback')

try:
    import webrtcvad
    print('✅ VAD enabled - smart silence skipping')
except ImportError:
    print('⚠️  VAD not available - processing all audio')
"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  For more options, see QUICKSTART.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
