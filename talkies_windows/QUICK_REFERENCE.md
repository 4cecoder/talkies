# Talkies Windows - Quick Reference Guide

## Getting Started

### First Launch
1. **Select Microphone**: Choose your input device from the "Microphone" dropdown
2. **Choose Model**: Select transcription model (recommend "base" for balanced speed/accuracy)
3. **Test Audio**: Click "Start Recording" and speak to test your microphone

### Basic Recording
1. Click **"Start Recording"** or press **Right Alt** (tap)
2. Speak clearly into your microphone
3. Click **"Stop Recording"** or press **Right Alt** again
4. Wait for transcription to complete
5. View transcript in the right panel

## Transcription Settings

### Model Selection
- **tiny**: Fastest, lowest accuracy (small models)
- **base**: Balanced speed and accuracy (recommended)
- **small**: Better accuracy, slower
- **medium**: High accuracy, slow
- **large**: Highest accuracy, slowest

### Language
- Auto-detect or select specific language
- Improves accuracy when language is known

### Voice Activity Detection (VAD)
- ✅ **Enabled**: Ignores silence, faster processing
- ☐ **Disabled**: Processes all audio

### Hallucination Filter
- ✅ **Enabled**: Removes duplicate/false text segments
- ☐ **Disabled**: Raw transcription output

## LLM Enhancement

### Enable Enhancement
1. Check "Enable LLM Enhancement"
2. Select provider (Ollama or LM Studio)
3. Set endpoint URL (auto-filled for defaults)
4. Click "Fetch Models" to discover available models
5. Select a model from the dropdown
6. Choose enhancement mode

### Providers

#### Ollama
- **Endpoint**: `http://localhost:11434` (default)
- **Popular Models**: llama2, llama3.2, mistral, neural-chat
- **Setup**: `ollama pull llama2` then `ollama serve`

#### LM Studio
- **Endpoint**: `http://127.0.0.1:1234` (default)
- **Setup**: Download from https://lmstudio.ai, load a model, start server

### Enhancement Modes
- **Grammar**: Fix grammatical errors and punctuation
- **Concise**: Shorten and clarify the text
- **Detailed**: Expand and add detail
- **Creative**: Rephrase creatively

### Troubleshooting Model Fetch
If "Fetch Models" fails:
- Verify provider is running and accessible
- Check endpoint URL is correct
- Ensure firewall isn't blocking connection
- Try `http://127.0.0.1` instead of `localhost`

## Export Transcript

### Formats Available
- **SRT**: SubRip subtitle format (for video subtitles)
- **TXT**: Plain text with timestamps
- **VTT**: WebVTT subtitle format (for video/web)

### How to Export
1. After transcription completes
2. Click desired export button (Export SRT, Export TXT, Export VTT)
3. Choose location and filename
4. File is saved automatically

### File Format Examples

**SRT Example:**
```
1
00:00:00,000 --> 00:00:05,123
This is the first subtitle
```

**TXT Example:**
```
[00:00:00.000] This is the first subtitle
[00:00:05.123] This is the second subtitle
```

**VTT Example:**
```
WEBVTT

00:00:00.000 --> 00:00:05.123
This is the first subtitle
```

## Hotkey Control

### Right Alt Key
- **Tap**: Start/Stop recording (toggle)
- **Hold**: Push-to-talk (records while held, stops when released)

### Hotkey Status
Shows current state:
- "Ready" - No operation in progress
- "Tap" - Toggled recording state
- "Hold (push-to-talk)" - Holding for continuous recording
- "Transcribing..." - Processing audio
- "Error: [message]" - Something went wrong

## Additional Features

### Text-to-Speech (TTS)
- Check "Speak response (TTS)" to hear the transcript read aloud
- Works with original or enhanced text
- Requires system speech synthesizer

### Text Injection
- Check "Insert text after transcription"
- Automatically types transcript into active window
- Useful for forms, documents, chat applications
- ⚠️ Place cursor in target window before starting recording

## Statistics

### Real-time Metrics
- **Segments**: Number of transcribed segments
- **Words**: Total word count
- **WPM**: Words per minute (calculated from recording length)

### Elapsed Time
Shows recording duration in MM:SS format

## Settings & Persistence

### Auto-saved Settings
- Selected transcription model
- Selected language
- Microphone device
- LLM provider and endpoint
- Selected LLM model
- Enhancement mode
- Feature toggles (VAD, filter, TTS, injection)

### Settings Location
Windows: `%USERPROFILE%\.talkies\config.json`

### Reset Settings
Delete the JSON file or let app recreate with defaults

## Common Workflows

### Transcribe & Export Meeting
1. Record meeting audio
2. Stop recording, wait for transcription
3. Click "Export SRT" for subtitle format
4. Use in video editor or media player

### Transcribe & Enhance for Documentation
1. Record voice notes
2. Stop recording, wait for transcription
3. Enable LLM enhancement with "Detailed" mode
4. Enhanced text appears in transcript
5. Export as TXT or SRT

### Real-time Dictation
1. Open your document/form
2. Click in text field
3. Enable "Insert text after transcription"
4. Start recording (Right Alt tap)
5. Speak clearly
6. Stop recording (Right Alt tap)
7. Text automatically inserted into active window

### Create Video Subtitles
1. Record video narration or extract audio
2. Transcribe audio
3. Click "Export SRT"
4. Use SRT file in video editor (Premiere, DaVinci, CapCut)
5. Subtitles sync with video

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle Recording | Right Alt (tap) |
| Push-to-Talk | Right Alt (hold) |
| (Future) Open Settings | Ctrl+, |
| (Future) Export Options | Ctrl+E |

## Troubleshooting

### No Audio Input
- Check microphone is plugged in and enabled
- Select correct device in "Microphone" dropdown
- Check system audio settings
- Test microphone in Windows Sound settings

### Transcription Accuracy Poor
- Try larger model (base → small → medium)
- Reduce background noise
- Ensure microphone is positioned well
- Speak clearly and at normal pace
- Select correct language

### LLM Enhancement Not Working
- Verify provider is running
- Check endpoint URL is accessible
- Try "Fetch Models" button again
- Check system firewall settings
- Review provider logs for errors

### Text Injection Not Working
- Ensure target window is focused before starting recording
- Some applications don't support text input
- Try different application
- Check "Insert text after transcription" is enabled

### Application Crashes
- Check Windows Event Viewer for error details
- Restart application
- Reinstall application
- Report bug with error message and steps to reproduce

## Tips & Tricks

### Performance Optimization
- Use smaller models (tiny, base) for faster transcription
- Disable VAD only if needed for accuracy
- Close other applications to free up memory
- Disable TTS if not using audio output

### Accuracy Improvement
- Speak at moderate pace (not too fast)
- Enunciate clearly
- Minimize background noise
- Use headset microphone for better input
- Pre-select language if known
- Use "Detailed" enhancement mode to add missing context

### Workflow Efficiency
- Use hotkey (Right Alt) instead of clicking buttons
- Set your preferred model/language once, settings persist
- Use TTS to verify transcription accuracy
- Export in batch if doing multiple files

### Advanced Configuration
- Manual provider endpoint for custom LLM servers
- Different models for different use cases
- Enhancement mode selection for different outputs
- Custom settings via JSON file (advanced users)

## System Requirements

- **OS**: Windows 10 or later
- **Memory**: 4GB minimum (8GB recommended for larger models)
- **Disk**: 2GB free (for whisper models)
- **Audio**: Any connected microphone
- **Network**: Required for LLM provider communication (optional feature)

## Getting Help

### Check Logs
- Application logs appear in status messages
- System logs in Windows Event Viewer

### Common Issues & Solutions
See "Troubleshooting" section above

### Report Issues
- Include error message
- Describe steps to reproduce
- Mention OS version and hardware specs
- Attach settings file if relevant

---

**Version**: 1.0  
**Last Updated**: 2024  
**Application**: Talkies Windows Transcription
