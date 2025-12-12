# Configuration Guide

## Configuration File

Whisper CLI uses a TOML configuration file located at `~/.whisper-cli.toml`. The configuration is optional but recommended for setting API keys and default preferences.

## Configuration Sections

### [whisper]
Core Whisper model settings.

```toml
[whisper]
model = "base"          # Model size: tiny, base, small, medium, large
device = "cpu"          # Device: cpu, cuda, auto
language = "en"         # Default language (auto-detect if not set)
vad_filter = true       # Voice activity detection
vad_threshold = 0.5     # VAD sensitivity (0.0-1.0)
```

### [ai_services]

#### Cloud AI Services (Optional - Requires API Keys)
```toml
[ai_services]
openai_api_key = "sk-..."          # OpenAI API key
anthropic_api_key = "sk-ant-..."   # Anthropic API key
groq_api_key = "gsk_..."           # Groq API key
deepl_api_key = "..."              # DeepL API key
elevenlabs_api_key = "..."         # ElevenLabs API key
deepgram_api_key = "..."           # Deepgram API key
```

#### Local AI Services (Automatic Fallback - No API Keys Needed)
```toml
[ai_services]
ollama_url = "http://localhost:11434"    # Local Ollama server URL
lmstudio_url = "http://localhost:1234"   # Local LM Studio server URL
```

**Note**: When no cloud API keys are configured, Whisper CLI will automatically use local AI services (LM Studio or Ollama) for text improvement and translation if available. This keeps your data private and works offline.

## API Keys Setup

### OpenAI
1. Go to [OpenAI API](https://platform.openai.com/api-keys)
2. Create a new API key
3. Add to config: `openai_api_key = "sk-..."`

### Anthropic
1. Go to [Anthropic Console](https://console.anthropic.com/)
2. Create API key
3. Add to config: `anthropic_api_key = "sk-ant-..."`

### Groq
1. Go to [Groq Console](https://console.groq.com/)
2. Create API key
3. Add to config: `groq_api_key = "gsk_..."`

### DeepL
1. Go to [DeepL API](https://www.deepl.com/pro-api)
2. Sign up for API access
3. Add to config: `deepl_api_key = "..."`

### ElevenLabs
1. Go to [ElevenLabs](https://elevenlabs.io/)
2. Create API key
3. Add to config: `elevenlabs_api_key = "..."`

### Deepgram
1. Go to [Deepgram](https://console.deepgram.com/)
2. Create API key
3. Add to config: `deepgram_api_key = "..."`

### Ollama (Local AI - Default Fallback)
1. Install [Ollama](https://ollama.ai/)
2. Pull a model: `ollama pull llama3.2`
3. Start Ollama: `ollama serve`
4. Configure URL if needed: `ollama_url = "http://localhost:11434"`

### LM Studio (Local AI - Alternative)
1. Install [LM Studio](https://lmstudio.ai/)
2. Download and load a model (e.g., Llama 3.2)
3. Start the local server in LM Studio
4. Configure URL if needed: `lmstudio_url = "http://localhost:1234"`

### [recording]
Audio recording settings.

```toml
[recording]
sample_rate = 16000     # Sample rate in Hz
channels = 1            # Number of channels (1=mono, 2=stereo)
chunk_size = 1024       # Audio chunk size
device_index = 0        # Audio device index (-1 for default)
```

### [output]
Output formatting options.

```toml
[output]
format = "txt"          # Default output format: txt, srt, vtt, json
timestamp_format = "%H:%M:%S"  # Timestamp format for SRT/VTT
max_line_length = 80    # Maximum characters per line
include_confidence = false  # Include confidence scores in JSON
```

### [batch]
Batch processing settings.

```toml
[batch]
max_concurrent = 4      # Maximum concurrent transcriptions
retry_failed = true     # Retry failed transcriptions
retry_attempts = 3      # Number of retry attempts
progress_bar = true     # Show progress bar
```

### [watch]
Watch folder settings.

```toml
[watch]
poll_interval = 1.0     # Folder polling interval in seconds
file_stability = 2.0    # Wait time before processing new files
ignore_patterns = ["*.tmp", "*.lock"]  # Files to ignore
recursive = true        # Watch subdirectories
```

### [webhooks]
Webhook integration settings.

```toml
[webhooks]
make_com_url = "https://hook.eu1.make.com/..."
n8n_url = "https://your-n8n-instance.com/webhook/..."
zapier_url = "https://hooks.zapier.com/hooks/catch/..."
custom_url = "https://your-custom-endpoint.com/..."
timeout = 30            # Webhook timeout in seconds
retries = 3             # Number of webhook retries
```

## Environment Variables

You can also set configuration via environment variables:

```bash
export WHISPER_CLI_MODEL=large
export WHISPER_CLI_DEVICE=cuda
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
```

Environment variables take precedence over config file settings.

## Runtime Configuration

Some settings can be overridden at runtime using CLI flags:

```bash
# Override model
./run.sh transcribe audio.mp3 --model large

# Override output format
./run.sh transcribe audio.mp3 --format srt

# Override language
./run.sh transcribe audio.mp3 --language es
```

## Advanced Configuration

### Custom Models
For custom GGML models:

```toml
[whisper]
model_path = "/path/to/custom/model.bin"
model_type = "ggml"
```

### Proxy Settings
For network requests:

```toml
[network]
http_proxy = "http://proxy.company.com:8080"
https_proxy = "http://proxy.company.com:8080"
no_proxy = "localhost,127.0.0.1"
```

### Logging
Debug logging configuration:

```toml
[logging]
level = "INFO"          # DEBUG, INFO, WARNING, ERROR
file = "~/whisper-cli.log"  # Log file path
max_size = 10485760     # Max log file size in bytes
backup_count = 5        # Number of backup log files
```

## Validation

The configuration is validated on startup. Invalid settings will show warnings and fall back to defaults.

```bash
# Check configuration
./run.sh config validate
```

## Examples

### Minimal Configuration
```toml
[whisper]
model = "base"

[ai_services]
openai_api_key = "sk-your-key-here"
```

### Full Configuration
See the example `config.example.toml` in the repository.

### Per-Project Configuration
You can use different configs for different projects:

```bash
./run.sh --config ./project-config.toml transcribe audio.mp3
```