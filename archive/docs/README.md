# Whisper CLI

A fast, modular CLI tool for audio transcription using Whisper and various AI services.

## Features

### 🔧 Core Functionality (Works Locally)
- **Transcription**: Transcribe audio files using Faster Whisper models
- **Batch Processing**: Transcribe multiple files at once
- **Watch Folders**: Automatically transcribe new audio files in a directory
- **YouTube Support**: Transcribe YouTube videos directly
- **Audio Recording**: Record audio from microphone or system
- **Multiple Formats**: Output in TXT, SRT, VTT, JSON formats
- **Webhook Integration**: Send transcripts to Make.com, n8n, Zapier

### 🤖 AI Enhancement (Local or Cloud)
- **Local AI**: Improve transcripts with Ollama or LM Studio (no API keys needed)
- **Cloud AI**: Enhance with OpenAI, Anthropic, Groq (requires API keys)
- **Speaker Recognition**: Add speaker labels (ElevenLabs, Deepgram - requires API keys)
- **Translation**: Translate transcripts using Whisper or AI services

## 🔒 Privacy & Local vs Cloud

Whisper CLI is designed to work **primarily locally** with no external dependencies:

- ✅ **Works offline**: Core transcription uses local Whisper models
- ✅ **No data sent to cloud**: Unless you explicitly configure cloud APIs
- ✅ **Local AI enhancement**: Ollama/LM Studio work offline
- ✅ **Your data stays private**: Only cloud features require external APIs

**Cloud features** (optional, require API keys):
- OpenAI, Anthropic, Groq for advanced AI enhancement
- ElevenLabs, Deepgram for speaker recognition
- DeepL for translation

## Installation

1. Install uv: `pip install uv`
2. Clone this repo
3. Run `./run.sh --help`

## Configuration

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

## Usage

### Check System Compatibility
```bash
# Show system information and capabilities
./run.sh system

# Get recommended configuration for your system
./run.sh system --recommend
```

### Transcribe a file
```bash
./run.sh transcribe audio.mp3 --model large --language en
```

### Batch transcribe
```bash
./run.sh batch /path/to/audio/files --output-dir /path/to/output
```

### Watch folder
```bash
./run.sh watch /path/to/watch --output-dir /path/to/output
```

### Record and transcribe
```bash
./run.sh record --duration 30 --output recording.wav
./run.sh transcribe recording.wav
```

### Transcribe YouTube
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