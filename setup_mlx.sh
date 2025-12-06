#!/bin/bash
# Setup MLX Whisper with Hugging Face

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 MLX Whisper Setup for M4 Mac"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "MLX Whisper models are available on Hugging Face:"
echo "  https://huggingface.co/collections/mlx-community/whisper-663256f9964fbb1177db93dc"
echo ""

# Check if models are already cached
if [ -d "$HOME/.cache/huggingface/hub" ]; then
    echo "✓ Hugging Face cache directory exists"

    # Check for MLX models
    mlx_models=$(find "$HOME/.cache/huggingface/hub" -type d -name "*mlx-community*whisper*" 2>/dev/null | wc -l)
    if [ $mlx_models -gt 0 ]; then
        echo "✓ Found $mlx_models MLX Whisper model(s) in cache"
    else
        echo "⚠️  No MLX models cached yet"
    fi
else
    echo "⚠️  No Hugging Face cache yet"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "To download MLX models, you have two options:"
echo ""
echo "Option 1: Automatic (when you run talkies)"
echo "  Models download automatically on first use"
echo "  ./run.sh live --model medium"
echo ""
echo "Option 2: Manual pre-download"
echo "  pip install huggingface-hub"
echo "  huggingface-cli download mlx-community/whisper-tiny-mlx"
echo "  huggingface-cli download mlx-community/whisper-base-mlx"
echo "  huggingface-cli download mlx-community/whisper-small-mlx"
echo "  huggingface-cli download mlx-community/whisper-medium-mlx"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "If you get 401 authentication errors:"
echo ""
echo "1. The models are public and should work without auth"
echo "2. If issues persist, talkies will automatically fall back"
echo "   to faster-whisper (still fast on M4!)"
echo ""
echo "Current status: talkies tries MLX first, falls back to faster-whisper"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Test it now:"
echo "  ./run.sh live --model tiny --duration 5"
echo ""
