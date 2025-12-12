# Usage Guide

## Basic Usage

### System Compatibility Check

Before using Whisper CLI, check your system's capabilities:

```bash
# View system information
./run.sh system

# Get recommended configuration
./run.sh system --recommend
```

This will show you available hardware acceleration, audio devices, and local AI services.

### Single File Transcription

The most common use case is transcribing a single audio file:

```bash
# Basic transcription
./run.sh transcribe audio.mp3

# With specific model
./run.sh transcribe audio.mp3 --model large

# Output as subtitles
./run.sh transcribe audio.mp3 --format srt --output subtitles.srt
```

### Supported Audio Formats

Whisper CLI supports all common audio formats:
- MP3 (.mp3)
- WAV (.wav)
- FLAC (.flac)
- M4A (.m4a)
- OGG (.ogg)
- AAC (.aac)
- And more...

### Output Formats

#### Text (txt)
Plain text transcript:
```
This is a sample transcript. It contains the full text of the audio file.
```

#### SRT (srt)
SubRip subtitle format:
```
1
00:00:00,000 --> 00:00:05,000
This is a sample transcript.

2
00:00:05,000 --> 00:00:10,000
It contains the full text of the audio file.
```

#### VTT (vtt)
WebVTT format:
```
WEBVTT

00:00:00.000 --> 00:00:05.000
This is a sample transcript.

00:00:05.000 --> 00:00:10.000
It contains the full text of the audio file.
```

#### JSON (json)
Structured data with timestamps and metadata:
```json
{
  "text": "This is a sample transcript. It contains the full text of the audio file.",
  "language": "en",
  "segments": [
    {
      "start": 0.0,
      "end": 5.0,
      "text": "This is a sample transcript."
    },
    {
      "start": 5.0,
      "end": 10.0,
      "text": "It contains the full text of the audio file."
    }
  ]
}
```

## Advanced Features

### AI-Powered Improvements

Enhance transcripts with AI services (uses Ollama locally by default, or cloud APIs if configured):

```bash
# Improve punctuation and grammar
./run.sh transcribe audio.mp3 --improve

# Translate to another language
./run.sh transcribe audio.mp3 --translate es
```

**Note**: AI features work out-of-the-box with local AI (Ollama or LM Studio). For cloud AI services, configure API keys in `~/.whisper-cli.toml`.

### Speaker Recognition

Identify different speakers in the audio:

```bash
# Enable speaker recognition
./run.sh transcribe audio.mp3 --speakers
```

### Batch Processing

Process multiple files at once:

```bash
# Process all audio files in directory
./run.sh batch ./audio_files

# Recursive processing
./run.sh batch ./audio_files --recursive

# Custom output directory
./run.sh batch ./audio_files --output-dir ./transcripts
```

### Watch Folders

Automatically transcribe new files:

```bash
# Watch current directory
./run.sh watch .

# Watch specific directory
./run.sh watch ./incoming_audio --output-dir ./processed
```

### Audio Recording

Record audio directly:

```bash
# Record for 30 seconds
./run.sh record --duration 30

# Record to specific file
./run.sh record --output meeting.wav

# Record continuously (Ctrl+C to stop)
./run.sh record
```

### YouTube Transcription

Transcribe YouTube videos:

```bash
# Basic YouTube transcription
./run.sh youtube "https://www.youtube.com/watch?v=VIDEO_ID"

# Output as subtitles
./run.sh youtube "https://youtu.be/VIDEO_ID" --format srt
```

## Workflow Examples

### Podcast Transcription Pipeline

```bash
# 1. Record podcast episode
./run.sh record --duration 3600 --output podcast_episode.wav

# 2. Transcribe with speaker recognition
./run.sh transcribe podcast_episode.wav --speakers --model large

# 3. Improve with AI
./run.sh transcribe podcast_episode.wav --improve --format srt
```

### Meeting Transcription

```bash
# Record meeting
./run.sh record --output meeting.wav

# Transcribe with timestamps
./run.sh transcribe meeting.wav --format srt --output meeting.srt

# Translate for international team
./run.sh transcribe meeting.wav --translate es --output meeting_es.srt
```

### Video Subtitles

```bash
# Transcribe video audio
./run.sh transcribe video.mp4 --format srt --output video.srt

# Create translated subtitles
./run.sh transcribe video.mp4 --translate fr --format srt --output video_fr.srt
```

### Bulk Content Processing

```bash
# Set up watch folder for automatic processing
./run.sh watch ./incoming_media --recursive --format json

# Process existing files in batch
./run.sh batch ./media_library --recursive --max-concurrent 2
```

## Performance Optimization

### Model Selection

Choose the right model for your needs:

- **tiny**: Fastest, least accurate (~39 MB)
- **base**: Good balance (~74 MB)
- **small**: Better accuracy (~244 MB)
- **medium**: High accuracy (~769 MB)
- **large**: Best accuracy (~1550 MB)

```bash
# Fast processing
./run.sh transcribe audio.mp3 --model tiny

# High accuracy
./run.sh transcribe audio.mp3 --model large
```

### GPU Acceleration

Use GPU for faster processing:

```toml
# In ~/.whisper-cli.toml
[whisper]
device = "cuda"
```

### Batch Processing Tips

- Use smaller batches for memory-constrained systems
- Process similar-length files together
- Use `--max-concurrent` to control resource usage

```bash
# Limit concurrent transcriptions
./run.sh batch ./files --max-concurrent 2
```

## Integration Examples

### Make.com Integration

Send transcripts to Make.com workflows:

```bash
# Configure webhook in config
[webhooks]
make_com_url = "https://hook.eu1.make.com/your-webhook-id"

# Transcribe and send to Make.com
./run.sh transcribe audio.mp3 --webhook make
```

### Custom Webhooks

```bash
# Send to custom endpoint
./run.sh transcribe audio.mp3 --webhook "https://your-api.com/transcript"
```

### Scripting

Use in shell scripts:

```bash
#!/bin/bash
# transcribe.sh

AUDIO_FILE="$1"
OUTPUT_DIR="./transcripts"

./run.sh transcribe "$AUDIO_FILE" --output "$OUTPUT_DIR/$(basename "$AUDIO_FILE" .mp3).txt"
```

### Python Integration

```python
from whisper_cli.transcription import transcribe_file

# Programmatic usage
result = transcribe_file("audio.mp3", model="base", language="en")
print(result['text'])
```

## Troubleshooting

### Common Issues

1. **"Model not found"**
   - Models are downloaded automatically on first use
   - Check internet connection

2. **"CUDA out of memory"**
   - Use smaller model or CPU: `--device cpu`
   - Reduce batch size

3. **"Audio file corrupted"**
   - Verify file integrity
   - Try converting to WAV: `ffmpeg -i file.mp3 file.wav`

4. **"API rate limit"**
   - Wait before retrying
   - Check API key limits

### Debug Mode

Enable verbose logging:

```bash
export WHISPER_CLI_LOG_LEVEL=DEBUG
./run.sh transcribe audio.mp3
```

### Performance Monitoring

Check transcription progress:

```bash
# With progress bars (default)
./run.sh batch ./files

# Quiet mode
./run.sh batch ./files --quiet
```