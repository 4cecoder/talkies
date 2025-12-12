# Installation Guide

## Prerequisites

- Python 3.8 or higher
- uv package manager
- FFmpeg (for audio processing)

## Quick Start

1. **Install uv** (if not already installed):
   ```bash
   pip install uv
   ```

2. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd whisper-cli
   ```

3. **Install dependencies**:
   ```bash
   uv sync
   ```

4. **Check system compatibility**:
   ```bash
   ./run.sh system
   ```

5. **Run the CLI**:
   ```bash
   ./run.sh --help
   ```

## Configuration

See the [Configuration Guide](configuration.md) for detailed configuration options and API key setup.

### Optional: Local AI Setup (No API Keys Required)

For enhanced transcription without cloud services, you can set up local AI:

#### Ollama (Recommended)
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama3.2

# Start Ollama server
ollama serve
```

#### LM Studio (Alternative)
1. Download from [lmstudio.ai](https://lmstudio.ai/)
2. Load a model (e.g., Llama 3.2)
3. Start the local server in LM Studio

With local AI running, Whisper CLI will automatically use it for text improvement and translation without any API keys!

## Troubleshooting

### Common Issues

1. **"faster-whisper not found"**
   - Ensure dependencies are installed: `uv sync`
   - Check Python version: `python --version`

2. **"FFmpeg not found"**
   - Install FFmpeg: `brew install ffmpeg` (macOS) or `apt install ffmpeg` (Ubuntu)

3. **"CUDA not available"**
   - For GPU support, install CUDA and set `device = "cuda"` in config
   - Fallback to CPU: `device = "cpu"`

4. **"API key invalid"**
   - Verify API keys in config file
   - Check API key permissions and credits

### Performance Tips

- Use GPU for faster transcription: `device = "cuda"`
- Use smaller models for faster processing: `model = "base"`
- Enable VAD filtering for better accuracy: built-in in faster-whisper