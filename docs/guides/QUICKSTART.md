# Talkies - Real-Time VTT Quick Start

## What's New in v0.2.0

**Blazing-fast real-time VTT generation optimized for Apple Silicon M4!**

- ⚡ Real-time transcription with sub-second latency
- 🚀 MLX Whisper with Metal GPU acceleration (M4 optimized)
- 🎯 Voice Activity Detection (VAD) - only processes speech
- 🖥️ Clean Tkinter GUI or terminal interface
- 📝 Live VTT generation with timestamps
- 💾 Export to standard VTT format

## Installation

```bash
# Install dependencies (already done!)
uv sync

# You're ready to go!
```

## Usage

### Real-Time Terminal Mode

Watch transcription appear in the terminal:

```bash
# Basic usage (auto-detect language)
./run.sh live

# With specific language
./run.sh live --language en

# Use larger model for better accuracy
./run.sh live --model medium --language en

# Save to file automatically
./run.sh live --output meeting.vtt

# Record for specific duration
./run.sh live --duration 300 --output interview.vtt
```

## Model Selection

Choose based on your needs:

| Model    | Speed          | Accuracy | Use Case                |
|----------|----------------|----------|-------------------------|
| `tiny`   | Blazing fast   | Good     | Quick notes, testing    |
| `base`   | Very fast      | Better   | **Default, recommended**|
| `small`  | Fast           | Great    | Meetings, interviews    |
| `medium` | Moderate       | Excellent| Professional work       |
| `large`  | Slower         | Best     | Critical transcription  |

**On M4 Pro:** Even `medium` runs in real-time thanks to Metal acceleration!

## Performance Optimization

### Already Optimized For You:

1. **MLX Whisper** - Uses Apple's Metal framework for GPU acceleration
2. **Voice Activity Detection** - Skips silence, saves compute
3. **Smart Chunking** - 1-second chunks processed in parallel
4. **Zero-copy Buffers** - Direct memory access, no overhead

### Expected Performance on M4 Pro:

- `tiny`: < 100ms latency
- `base`: ~150ms latency (**recommended**)
- `small`: ~250ms latency
- `medium`: ~400ms latency (still real-time!)

## Examples

### Quick Meeting Notes

```bash
# Start GUI, speak naturally
./run.sh live --gui --model base

# Click "Start Recording"
# Speak: "Meeting with John about Q4 roadmap..."
# Click "Stop Recording"
# Click "Save VTT" → exports timestamped transcript
```

### Interview Transcription

```bash
# Terminal mode with auto-save
./run.sh live --model small --language en --output interview.vtt

# Speak naturally, transcription appears in real-time
# Press Ctrl+C when done
# File automatically saved to interview.vtt
```

### Multi-language Support

```bash
# Spanish
./run.sh live --gui --language es

# French
./run.sh live --gui --language fr

# Auto-detect (works great!)
./run.sh live --gui
```

## VTT Output Format

Your transcripts are saved in standard WebVTT format:

```vtt
WEBVTT

00:00:00.000 --> 00:00:02.500
Welcome to the meeting. Today we'll discuss...

00:00:02.500 --> 00:00:05.800
The Q4 roadmap includes three major features.

00:00:05.800 --> 00:00:09.200
First, we're launching the real-time VTT system...
```

Perfect for:
- Video subtitles
- Meeting minutes
- Interview transcripts
- Lecture notes
- Accessibility

## Hotkeys (GUI Mode)

- `Cmd+R` - Start/Stop Recording (coming soon)
- `Cmd+S` - Save VTT (coming soon)
- `Cmd+K` - Clear Text (coming soon)

## Tips for Best Results

1. **Speak Clearly** - Natural pace, enunciate
2. **Reduce Background Noise** - VAD helps but quiet is better
3. **Use Good Microphone** - Built-in Mac mic works great
4. **Choose Right Model** - `base` is fast and accurate for most use
5. **Set Language** - Better accuracy than auto-detect

## Troubleshooting

### "No audio input detected"

```bash
# List available microphones
./run.sh record --list-devices

# Use specific device
./run.sh live --device "MacBook Pro Microphone"
```

### "MLX not available"

Falls back to faster-whisper automatically. Still fast on M4!

### "Import Error: webrtcvad"

VAD disabled automatically. Everything still works, just processes silence too.

## What's Next?

Coming soon in v0.3.0:
- 🔥 System-wide hotkey (dictate into ANY app)
- 🧠 AI-powered auto-editing (remove filler words)
- 📚 Personal dictionary (learn your terminology)
- 🎯 Context-aware tone adjustment
- ⚡ Auto-insertion into active app

---

## Comparison: Talkies vs WhisperFlow

| Feature                  | Talkies v0.2    | WhisperFlow      |
|--------------------------|-----------------|------------------|
| Real-time Transcription  | ✅              | ✅               |
| VTT Output               | ✅              | ❌               |
| Open Source              | ✅ Free         | ❌ Paid          |
| Local-First              | ✅ Offline      | ⚠️ Cloud         |
| M4 Optimization          | ✅ MLX/Metal    | ⚠️ Generic       |
| File Transcription       | ✅              | ❌               |
| YouTube Transcription    | ✅              | ❌               |
| Multiple AI Backends     | ✅ 5+ options   | ❌ Proprietary   |
| System-wide Hotkey       | 🚧 Coming       | ✅               |
| Auto-editing             | 🚧 Coming       | ✅               |

**Talkies Advantage:** Open source, privacy-focused, multi-modal, M4-optimized, free!

---

## Get Started Now!

```bash
# Launch GUI
./run.sh live --gui

# Start talking!
```

Enjoy blazing-fast transcription on your M4 Pro! 🚀
