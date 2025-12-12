# API Reference

## Command Line Interface

### Global Options

- `--config PATH`: Path to config file (default: ~/.whisper-cli.toml)
- `--help`: Show help message
- `--version`: Show version

### transcribe

Transcribe a single audio file.

```bash
whisper-cli transcribe AUDIO_FILE [OPTIONS]
```

**Arguments:**
- `AUDIO_FILE`: Path to audio file (mp3, wav, flac, m4a, etc.)

**Options:**
- `--model TEXT`: Whisper model (tiny, base, small, medium, large) [default: base]
- `--language TEXT`: Language code (auto-detect if not specified)
- `--output, -o PATH`: Output file path
- `--format [txt|srt|vtt|json]`: Output format [default: txt]
- `--translate TEXT`: Translate to language code (uses local AI or cloud APIs)
- `--improve`: Improve punctuation and grammar with AI (uses local AI or cloud APIs)
- `--speakers`: Enable speaker recognition (requires ElevenLabs or Deepgram API keys)
- `--start-time TEXT`: Start timestamp (HH:MM:SS)
- `--end-time TEXT`: End timestamp (HH:MM:SS)
- `--vad-filter`: Enable voice activity detection
- `--no-vad-filter`: Disable voice activity detection

**Examples:**
```bash
# Basic transcription
whisper-cli transcribe audio.mp3

# With specific model and language
whisper-cli transcribe audio.mp3 --model large --language en

# Output as SRT subtitles
whisper-cli transcribe audio.mp3 --format srt --output subtitles.srt

# Improve with AI and translate
whisper-cli transcribe audio.mp3 --improve --translate es
```

### batch

Batch transcribe multiple files.

```bash
whisper-cli batch INPUT_DIR [OPTIONS]
```

**Arguments:**
- `INPUT_DIR`: Input directory containing audio files

**Options:**
- `--output-dir PATH`: Output directory for transcripts
- `--recursive, -r`: Process subdirectories
- `--pattern TEXT`: File pattern [default: *.{mp3,wav,flac,m4a}]
- `--model TEXT`: Whisper model
- `--format [txt|srt|vtt|json]`: Output format
- `--max-concurrent INTEGER`: Maximum concurrent transcriptions [default: 4]

**Examples:**
```bash
# Process all audio files in directory
whisper-cli batch ./audio_files

# Recursive processing with custom output
whisper-cli batch ./audio_files --recursive --output-dir ./transcripts
```

### watch

Watch a folder for new audio files and transcribe them automatically.

```bash
whisper-cli watch FOLDER [OPTIONS]
```

**Arguments:**
- `FOLDER`: Folder to watch for new files

**Options:**
- `--output-dir PATH`: Output directory for transcripts
- `--pattern TEXT`: File pattern to watch
- `--recursive, -r`: Watch subdirectories
- `--model TEXT`: Whisper model
- `--format [txt|srt|vtt|json]`: Output format

**Examples:**
```bash
# Watch current directory
whisper-cli watch .

# Watch with custom output directory
whisper-cli watch ./incoming --output-dir ./processed
```

### record

Record audio from microphone.

```bash
whisper-cli record [OPTIONS]
```

**Options:**
- `--duration INTEGER`: Recording duration in seconds
- `--output, -o PATH`: Output file path [default: recording.wav]
- `--device TEXT`: Audio device name or index
- `--sample-rate INTEGER`: Sample rate [default: 16000]
- `--channels INTEGER`: Number of channels [default: 1]

**Examples:**
```bash
# Record for 30 seconds
whisper-cli record --duration 30

# Record to specific file
whisper-cli record --output meeting.wav

# Record with specific device
whisper-cli record --device "USB Microphone"
```

### system

Show system information and capabilities.

```bash
whisper-cli system [OPTIONS]
```

**Options:**
- `--recommend`: Show recommended configuration for your system

**Examples:**
```bash
# Show system information
whisper-cli system

# Show recommended configuration
whisper-cli system --recommend
```

### youtube

Transcribe a YouTube video.

```bash
whisper-cli youtube URL [OPTIONS]
```

**Arguments:**
- `URL`: YouTube video URL

**Options:**
- `--output, -o PATH`: Output file path
- `--format [txt|srt|vtt|json]`: Output format
- `--model TEXT`: Whisper model
- `--language TEXT`: Language code

**Examples:**
```bash
# Transcribe YouTube video
whisper-cli youtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Output as subtitles
whisper-cli youtube "https://youtu.be/dQw4w9WgXcQ" --format srt
```

## Python API

### Core Classes

#### WhisperCLI

Main CLI class for programmatic use.

```python
from whisper_cli.cli import WhisperCLI

cli = WhisperCLI(config_path="~/.whisper-cli.toml")
```

#### Config

Configuration management.

```python
from whisper_cli.config import load_config, save_config

config = load_config("~/.whisper-cli.toml")
# Modify config
config['whisper']['model'] = 'large'
save_config(config, "~/.whisper-cli.toml")
```

### Transcription Functions

#### transcribe_file

```python
from whisper_cli.transcription import transcribe_file

result = transcribe_file(
    audio_path="audio.mp3",
    model="base",
    language="en",
    config=config,
    translate=None,
    speakers=False
)

print(result['text'])  # Full transcript
print(result['segments'])  # Segmented results with timestamps
```

**Parameters:**
- `audio_path` (Path): Path to audio file
- `model` (str): Whisper model name
- `language` (str, optional): Language code
- `config` (dict, optional): Configuration dictionary
- `translate` (str, optional): Target language for translation (uses local AI or cloud APIs)
- `speakers` (bool): Enable speaker recognition (requires ElevenLabs or Deepgram API keys)

**Returns:**
- `dict`: Transcription result with 'text' and 'segments' keys

#### save_transcript

```python
from whisper_cli.transcription import save_transcript

save_transcript(result, "output.txt", "txt")
save_transcript(result, "subtitles.srt", "srt")
```

**Parameters:**
- `result` (dict): Transcription result
- `output_path` (Path): Output file path
- `format` (str): Output format ('txt', 'srt', 'vtt', 'json')

### Batch Processing

#### batch_transcribe

```python
from whisper_cli.batch import batch_transcribe

batch_transcribe(
    input_dir="./audio",
    output_dir="./transcripts",
    recursive=True,
    pattern="*.{mp3,wav}",
    config=config
)
```

### AI Services

#### improve_transcript

```python
from whisper_cli.ai_services import improve_transcript

improved_text = improve_transcript(raw_text, config)
```

#### translate_text

```python
from whisper_cli.ai_services import translate_text

translated = translate_text(text, "es", config)
```

### Recording

#### record_audio

```python
from whisper_cli.record import record_audio

record_audio(
    output_path="recording.wav",
    duration=30,
    device="USB Microphone",
    config=config
)
```

### YouTube

#### transcribe_youtube

```python
from whisper_cli.youtube import transcribe_youtube

result = transcribe_youtube(
    "https://www.youtube.com/watch?v=VIDEO_ID",
    config=config
)
```

## Error Handling

All functions raise appropriate exceptions:

- `FileNotFoundError`: Audio file not found
- `ValueError`: Invalid parameters
- `ConnectionError`: Network/API errors
- `RuntimeError`: Processing errors

```python
try:
    result = transcribe_file("audio.mp3")
except FileNotFoundError:
    print("Audio file not found")
except ValueError as e:
    print(f"Invalid parameter: {e}")
except Exception as e:
    print(f"Transcription failed: {e}")
```

## Configuration Schema

```python
config = {
    'whisper': {
        'model': str,          # Model name
        'device': str,         # Device ('cpu', 'cuda')
        'language': str,       # Language code
        'vad_filter': bool,    # Voice activity detection
    },
    'ai_services': {
        'openai_api_key': str,
        'anthropic_api_key': str,
        'groq_api_key': str,
        # ... other API keys
    },
    'recording': {
        'sample_rate': int,
        'channels': int,
    },
    'output': {
        'format': str,
        'timestamp_format': str,
    }
}
```