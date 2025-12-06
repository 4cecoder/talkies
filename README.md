# Talkies (Whisper CLI v0.2.0)

**Blazing-fast real-time voice transcription optimized for Apple Silicon M4.**

The world's fastest open-source voice-to-VTT system with Metal GPU acceleration, Voice Activity Detection, and sub-second latency.

## 🚀 What's New in v0.2.0

- ⚡ **Real-Time VTT Streaming** - Live transcription with timestamps (< 200ms latency on M4)
- 🎯 **MLX Whisper** - Metal GPU acceleration for Apple Silicon
- 🖥️ **Native Dark-Mode GUI** - Professional desktop interface with PyQt6
- 🎤 **Voice Activity Detection** - Smart silence skipping
- 📝 **Live Display** - Watch transcription appear as you speak
- 🧹 **Hallucination Filter** - Removes common Whisper artifacts ("Thanks for watching", etc.)
- 📊 **Real-Time Statistics** - WPM tracking, word count, segment count

[**→ See QUICKSTART.md for real-time features**](./QUICKSTART.md) | [**→ See GUI.md for GUI guide**](./GUI.md)

## Core Features

### Real-Time (NEW!)
- **Live VTT Streaming**: Sub-second latency transcription with timestamps
- **M4 Optimization**: MLX Whisper with Metal GPU acceleration
- **Native GUI & CLI**: Dark-mode desktop app or terminal mode
- **VAD Enabled**: Only processes speech, saves compute
- **Hallucination Filter**: Automatically removes common Whisper artifacts
- **Live Statistics**: WPM, word count, segment tracking

### File Processing
- **Transcription**: Transcribe audio files using Faster Whisper models
- **Batch Processing**: Transcribe multiple files at once
- **Watch Folders**: Automatically transcribe new audio files in a directory
- **YouTube Support**: Transcribe YouTube videos directly
- **Audio Recording**: Record audio from microphone or system

### AI Integration
- **AI Enhancement**: Improve transcripts with local AI (Ollama/LM Studio) or cloud APIs (OpenAI, Anthropic, Groq, etc.)
- **Speaker Recognition**: Add speaker labels (ElevenLabs, Deepgram)
- **Translation**: Translate transcripts using Whisper or AI services

### Output & Integration
- **Multiple Formats**: Output in TXT, SRT, VTT, JSON formats
- **Webhook Integration**: Send transcripts to Make.com, n8n, Zapier

## Quick Start

### Installation

1. Install uv: `pip install uv`
2. Clone this repo
3. Run `uv sync` (installs all dependencies)
4. Ready to go!

### Real-Time VTT (NEW!)

```bash
# Launch native dark-mode GUI (recommended!)
./run.sh live --gui

# Terminal mode with live display
./run.sh live --language en

# Save to file
./run.sh live --output meeting.vtt

# Quick test (5 seconds, tiny for speed)
./run.sh live --model tiny --duration 5

# Best quality with GUI
./run.sh live --gui --model large

# CPU mode (no GPU)
./run.sh live --gui --cpu
```

[**→ Full real-time guide in QUICKSTART.md**](./QUICKSTART.md) | [**→ GUI guide in GUI.md**](./GUI.md)

### Basic Configuration

Create a config file at `~/.whisper-cli.toml`:

```toml
[whisper]
model = "base"
device = "cpu"

[ai_services]
# Cloud AI (optional)
openai_api_key = "your-key"
anthropic_api_key = "your-key"
groq_api_key = "your-key"
deepl_api_key = "your-key"

# Local AI (automatic fallback)
ollama_url = "http://localhost:11434"
lmstudio_url = "http://localhost:1234"

[recording]
sample_rate = 16000
channels = 1
```

### Basic Usage

#### Transcribe a file
```bash
./run.sh transcribe audio.mp3 --model large --language en
```

#### Batch transcribe
```bash
./run.sh batch /path/to/audio/files --output-dir /path/to/output
```

#### Watch folder
```bash
./run.sh watch /path/to/watch --output-dir /path/to/output
```

#### Record and transcribe
```bash
./run.sh record --duration 30 --output recording.wav
./run.sh transcribe recording.wav
```

#### Transcribe YouTube
```bash
./run.sh youtube "https://youtube.com/watch?v=..." --format srt
```

## Supported Models

- Tiny, Base, Small, Medium, Large (V2/V3)
- Custom GGML models
- Distilled models

## AI Services

- OpenAI (GPT-3.5, GPT-4)
- Anthropic (Claude)
- Groq (Llama)
- ElevenLabs (Speaker recognition)
- Deepgram (Speaker recognition, Nova)
- DeepL (Translation)

## Output Formats

- TXT: Plain text
- SRT: SubRip subtitle format
- VTT: WebVTT format
- JSON: Full transcription data with timestamps

## Documentation

- **[Installation Guide](docs/installation.md)** - Detailed installation and setup
- **[Configuration Guide](docs/configuration.md)** - Configuration options and API keys
- **[Usage Guide](docs/usage.md)** - Advanced usage, examples, and workflows
- **[API Reference](docs/api.md)** - Command reference and Python API
- **[Changelog](docs/changelog.md)** - Version history

## Support

- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **Email**: support@whisper-cli.com