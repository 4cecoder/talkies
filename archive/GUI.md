# Talkies Native Desktop GUI

Professional dark-mode GUI for real-time VTT transcription, optimized for M4.

## Launch

```bash
./run.sh live --gui
```

## Features

### Two-Panel Layout
- **Left Sidebar**: Controls, settings, and statistics (gradient purple/blue)
- **Right Panel**: Live transcript display with dark mode

### Real-Time Controls
- **Start/Stop Recording**: Large, prominent button
- **Save VTT**: Export to file with timestamped filename
- **Clear**: Remove all segments
- **Export**: Quick export from header

### Settings Panel
- **Model Selection**: tiny, base, small, medium, large, large-v3-turbo
- **Language Selection**: auto, en, es, fr, de, it, pt, ru, ja, zh, ko, ar, hi
- **VAD Toggle**: Enable/disable voice activity detection
- **Hallucination Filter**: Toggle artifact removal

### Live Statistics
- **Segments**: Total segment count
- **Words**: Total word count
- **WPM**: Words per minute (live calculation)

### Visual Features
- **Dark Mode**: Professional dark theme throughout
- **Animated Segments**: Smooth slide-in animations
- **Gradient Sidebar**: Purple/blue gradient with glassmorphism
- **Status Indicators**: Recording status with emoji icons
- **Live Timer**: MM:SS format
- **Backend Display**: Shows MLX (GPU) or CPU

### Transcript Display
- Individual segment cards with timestamps
- Hover effects on segments
- Auto-scroll to latest segment
- Empty state with instructions
- Smooth scrolling
- Custom dark scrollbar

## Usage Examples

```bash
# Basic launch with GUI
./run.sh live --gui

# Large model with GUI
./run.sh live --gui --model large

# Spanish transcription
./run.sh live --gui --language es

# CPU mode
./run.sh live --gui --cpu
```

## Keyboard Shortcuts

- **Cmd+W / Ctrl+W**: Close window (with confirmation if recording)

## Technical Details

### Architecture
- **PyQt6**: Professional native GUI framework
- **Threading**: Background transcription thread
- **Signals/Slots**: Thread-safe communication
- **Animations**: Qt property animations
- **High DPI**: Automatic scaling support

### Performance
- Zero impact on transcription performance
- GPU-accelerated rendering
- Efficient memory usage
- Real-time updates via Qt signals

### Compatibility
- ✅ macOS (native Fusion style)
- ✅ Linux (Fusion style)
- ✅ Windows (Fusion style)

## Design Philosophy

Inspired by WhisperFlow but with:
- **Native Performance**: No browser overhead
- **Dark Mode First**: Easy on the eyes
- **Professional UX**: Clean, spacious layout
- **M4 Optimized**: Takes full advantage of Metal GPU

## Features vs WhisperFlow

| Feature | Talkies GUI | WhisperFlow |
|---------|-------------|-------------|
| **Price** | Free | $19+/month |
| **Privacy** | 100% local | Cloud-based |
| **Speed** | M4 optimized | Internet dependent |
| **Customization** | Full control | Limited |
| **Dark Mode** | Yes | Unknown |
| **Settings** | In-app | Unknown |
| **Statistics** | Real-time WPM | Unknown |
| **Animations** | Smooth | Unknown |

## Screenshots

### Main Interface
- Left: Gradient sidebar with controls
- Right: Dark transcript panel with animated segments

### Recording State
- Red recording indicator
- Live timer
- Stop button active
- Save button disabled

### Stopped State
- Green ready indicator
- Save button enabled
- Export available

## Roadmap

Future enhancements:
- [ ] Custom themes
- [ ] Segment editing
- [ ] Search/filter segments
- [ ] Multiple export formats (SRT, JSON, TXT)
- [ ] Keyboard shortcuts for recording
- [ ] Mini mode (compact view)
- [ ] System tray integration
- [ ] Audio waveform visualization

---

**Enjoy the professional dark-mode GUI!** 🎉

Run `./run.sh live --gui` to get started.
