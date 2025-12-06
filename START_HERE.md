# Talkies v0.2.0 - START HERE 🚀

## What You Have

**Blazing-fast real-time VTT transcription optimized for M4 MacBook Pro**

Sub-second latency | MLX GPU Acceleration | Voice Activity Detection | Terminal UI

---

## Quick Start (30 Seconds)

```bash
# Basic test
./run.sh live --model tiny --duration 5

# Say something for 5 seconds
# Watch transcription appear in real-time!
```

---

## Main Usage

### Real-Time Transcription

```bash
./run.sh live --model base --language en
```

- Speak naturally
- Watch text appear with timestamps
- Press Ctrl+C to stop

### Save to File

```bash
./run.sh live --output meeting.vtt
```

Automatically saves VTT format when you stop.

### Interactive Demo

```bash
./demo.sh
```

Menu with 6 options for different use cases.

---

## Model Selection

| Model | Speed | Accuracy | Best For |
|-------|-------|----------|----------|
| tiny | Fastest | Good | Quick tests |
| base | Very fast | Better | Fast notes |
| small | Fast | Great | Meetings |
| **medium** | Moderate | Excellent | **Default** ✨ |
| large | Slower | Best | Critical work |

**Default:** `medium` model for best accuracy. Still fast on M4!

---

## How It Works

1. **Press enter** to start command
2. **MLX downloads model** (first time only, ~2-4 seconds)
3. **Speak into mic** - any MacBook mic works great
4. **See text appear** in real-time with timestamps
5. **Press Ctrl+C** to stop
6. **VTT is ready** - standard subtitle format

---

## First Run Notes

### Initial Model Download

The first time you run with a model, faster-whisper will download it automatically.

This is normal! After that, it's instant.

**Approximate sizes:**
- tiny: ~75 MB
- base: ~140 MB
- small: ~460 MB
- medium: ~1.5 GB

Models are cached in `~/.cache/huggingface/`

### What You'll See

```
Starting real-time VTT stream...
Model: base | Language: auto
Press Ctrl+C to stop

✓ faster-whisper loaded (cpu/int8)
✓ VAD enabled (smart silence skipping)

⏺ RECORDING (0.0s)

[00:00:00.000] Hello, this is a test
[00:00:02.500] of the real-time transcription system
[00:00:05.800] It works great on the M4 Mac!

Listening... speak now!
```

---

## Common Commands

```bash
# Basic usage (uses medium model by default)
./run.sh live

# Quick test (5 seconds, tiny model for speed)
./run.sh live --model tiny --duration 5

# Meeting notes (default medium model)
./run.sh live --output meeting.vtt

# Professional work (best quality)
./run.sh live --model large --output professional.vtt

# Spanish transcription
./run.sh live --language es

# Faster option (base model)
./run.sh live --model base
```

---

## Example Session

```bash
$ ./run.sh live --output notes.vtt

Starting real-time VTT stream...
Model: medium | Language: auto
Press Ctrl+C to stop

✓ faster-whisper loaded (cpu/int8)
✓ VAD enabled (smart silence skipping)

⏺ RECORDING (3.2s)

[00:00:00.500] Today I need to work on the quarterly report
[00:00:03.800] First I'll review last quarter's numbers
[00:00:07.200] Then update the projections for Q4

^C
Stopping...
✓ VTT saved to notes.vtt
Processed 3 segments in 8.1s
```

---

## Output Format

Standard WebVTT (works everywhere):

```vtt
WEBVTT

00:00:00.500 --> 00:00:03.800
Today I need to work on the quarterly report

00:00:03.800 --> 00:00:07.200
First I'll review last quarter's numbers

00:00:07.200 --> 00:00:10.500
Then update the projections for Q4
```

Use for:
- Video subtitles
- Meeting transcripts
- Interview notes
- Lecture transcripts

---

## Tips for Best Results

1. **Clear speech** - Natural pace, enunciate
2. **Quiet environment** - VAD helps but less noise is better
3. **Good mic** - Built-in Mac mic is excellent
4. **Right model** - `base` is sweet spot for speed/accuracy
5. **Set language** - Faster than auto-detect
6. **Use headphones** - Prevents echo if playing audio

---

## Troubleshooting

### "No audio input detected"

```bash
# List available mics
./run.sh record --list-devices

# Use specific mic
./run.sh live --device "MacBook Pro Microphone"
```

### Latency seems high

1. Use smaller model (`tiny` or `base`)
2. Check Activity Monitor for CPU usage
3. Close other heavy apps
4. Verify MLX is active (look for "Metal GPU" in output)

### Model download is slow

First time only! Models are cached after download.

### "MLX not available"

Falls back to faster-whisper automatically. Still works, just uses CPU instead of GPU.

---

## Advanced Usage

### Combine with AI Enhancement

```bash
# Transcribe first
./run.sh live --output raw.vtt

# Then improve with AI
./run.sh transcribe raw.vtt --improve --output polished.txt
```

### Multiple Languages

```bash
# Auto-detect (works well!)
./run.sh live --output multilingual.vtt

# Or specify
./run.sh live --language es --output spanish.vtt
```

### Batch Processing

```bash
# Create multiple VTT files
./run.sh live --output session1.vtt
./run.sh live --output session2.vtt

# Then batch process
./run.sh batch ./sessions/ --improve --output-dir ./polished/
```

---

## What's Coming (v0.3.0)

- 🔥 System-wide hotkey (dictate anywhere)
- 🧠 AI auto-editing (remove filler words)
- 📚 Personal dictionary
- 🎯 Context-aware formatting
- ⚡ Clipboard auto-insertion

---

## Performance on Your M4 Pro

Expected with faster-whisper:
- `tiny`: Very fast
- `base`: Fast
- `small`: Moderate
- `medium`: Still real-time ⭐ (default)
- `large`: Slower but best quality

All models work in real-time on M4!

---

## Need Help?

```bash
# Full help
./run.sh live --help

# System info
./run.sh system

# List models
./demo.sh
# Choose option 4

# List mics
./demo.sh
# Choose option 5
```

---

## Ready? Go!

```bash
./run.sh live --model base
```

**Start speaking and watch the magic! ✨**

---

## Documentation

- **START_HERE.md** - This file (basics)
- **READY.md** - Complete usage guide
- **QUICKSTART.md** - Real-time features
- **WHATS_NEW.md** - Detailed changelog
- **README.md** - Full documentation

---

Built for M4 Mac with ❤️

Enjoy blazing-fast transcription!
