# Talkies Wayland Visual Overlay

This document explains how to use the visual overlay system for Talkies on Wayland/Hyprland.

## Architecture

Talkies uses **file-based IPC** to communicate between components:

- **State File**: `/tmp/talkies-state` - Contains current state: `idle`, `recording`, or `processing`
- **Waveform File**: `/tmp/talkies-waveform` - Contains 40 float values (0.0-1.0) for waveform visualization
- **Recording File**: `/tmp/talkies-recording.wav` - Temporary audio capture

## Components

### 1. Daemon (`talkies daemon`)
**Purpose**: Background process that handles transcription

**Location**: `zig-out/bin/talkies daemon`

**What it does**:
- Monitors `/tmp/talkies-state` every 100ms
- When state changes to `processing`:
  - Transcribes `/tmp/talkies-recording.wav`
  - Pastes result to active window
  - Resets state to `idle`
- Prints status messages to terminal (clean, no waveform)

**Usage**:
```bash
cd ~/talkies/linux
zig build run -- daemon
```

### 2. Toggle Script (`talkies-toggle.sh`)
**Purpose**: Triggered by Super+Alt+T hotkey to start/stop recording

**Location**: `~/.config/hypr/scripts/talkies-toggle.sh`

**What it does**:
- **On first press** (idle → recording):
  - Sets state to `recording`
  - Starts `arecord` to capture audio
  - Starts waveform monitor (generates random levels for now)
- **On second press** (recording → processing):
  - Sets state to `processing`
  - Stops `arecord`
  - Clears waveform
  - Daemon detects state change and processes

**Hyprland config**:
```
bind = SUPER_ALT, T, exec, bash ~/.config/hypr/scripts/talkies-toggle.sh
```

### 3. Visual Overlays (Choose ONE or BOTH)

#### Option A: AGS Widget (Integrated)
**Purpose**: Pill-shaped overlay integrated with AGS status bar

**Location**: `~/.config/ags/widgets/talkies.js`

**Features**:
- 🔴 Pulsing red dot when recording
- ⚙️ Gear icon when processing
- 40-bar animated waveform
- Recording duration timer
- Auto-shows on recording, hides when idle

**Setup**:
1. Import in your `~/.config/ags/config.js`:
   ```javascript
   import { TalkiesOverlay } from './widgets/talkies.js';

   // Add to your windows array:
   TalkiesOverlay(),
   ```

2. Restart AGS:
   ```bash
   ags quit && ags &
   ```

**Customization**:
- Change colors in CSS (line 133-138)
- Adjust position with `anchor` (line 125)
- Modify update rate with poll interval (line 35, 151)

#### Option B: Standalone GTK Overlay (Universal)
**Purpose**: Independent overlay that works without AGS

**Location**: `/home/fource/talkies/linux/talkies-overlay-gtk`

**Features**:
- Same visual design as AGS widget
- Runs as separate Python process
- Works on any compositor (GNOME, KDE, Sway, etc.)
- Requires GTK4

**Usage**:
```bash
# Start overlay (run in background)
~/talkies/linux/talkies-overlay-gtk &

# Or add to Hyprland autostart
exec-once = ~/talkies/linux/talkies-overlay-gtk
```

**Dependencies**:
```bash
# Gentoo
emerge dev-python/pygobject gui-libs/gtk:4

# Ubuntu/Debian
apt install python3-gi gir1.2-gtk-4.0
```

## Complete Workflow

### Terminal Session 1: Start Daemon
```bash
cd ~/talkies/linux
zig build run -- daemon
```

**Expected output**:
```
🎙️  Talkies daemon started (Wayland mode)
📁 State file: /tmp/talkies-state
📂 Recording: /tmp/talkies-recording.wav
🔧 Monitoring state changes...
```

### Terminal Session 2: Start Overlay (Optional)
```bash
# If using standalone GTK (not AGS):
~/talkies/linux/talkies-overlay-gtk &
```

### Recording Workflow
1. **Press Super+Alt+T**: Start recording
   - Overlay appears with red pulsing dot
   - Waveform animates
   - Timer counts up

2. **Speak your message**: Audio is captured to `/tmp/talkies-recording.wav`

3. **Press Super+Alt+T again**: Stop recording
   - Overlay shows "Processing" with gear icon
   - Daemon transcribes audio
   - Text pasted to active window
   - Overlay disappears

**Daemon terminal shows**:
```
⚙️  Processing transcription...
✨ Transcription: "Hello, this is a test recording"
📋 Copied to clipboard
⌨️  Pasted to active window
```

## State Flow Diagram

```
┌──────────────────────────────────────────────────────┐
│ User presses Super+Alt+T                            │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
     ┌─────────────────────┐
     │   STATE = "idle"    │
     └─────────┬───────────┘
               │ Toggle script: echo "recording" > /tmp/talkies-state
               │                arecord starts
               ▼
     ┌─────────────────────┐
     │ STATE = "recording" │◄─── Overlay shows waveform
     └─────────┬───────────┘     Timer counts up
               │
               │ User presses Super+Alt+T again
               │ Toggle script: echo "processing" > /tmp/talkies-state
               │                arecord stops
               ▼
     ┌─────────────────────┐
     │ STATE = "processing"│◄─── Overlay shows "Processing"
     └─────────┬───────────┘     Daemon detects state change
               │
               │ Daemon: whisper_service.transcribe()
               │         clipboard.copy(text)
               │         input.paste()
               │         echo "idle" > /tmp/talkies-state
               ▼
     ┌─────────────────────┐
     │   STATE = "idle"    │◄─── Overlay hides
     └─────────────────────┘
```

## Troubleshooting

### Overlay doesn't appear
**Check**:
1. Is daemon running? `pgrep -f "talkies daemon"`
2. Does state file exist? `cat /tmp/talkies-state`
3. AGS running? `ps aux | grep ags`
4. GTK overlay running? `ps aux | grep talkies-overlay-gtk`

**Fix**:
```bash
# Restart daemon
pkill -f "talkies daemon"
cd ~/talkies/linux && zig build run -- daemon &

# Restart AGS
ags quit && ags &

# Or restart GTK overlay
pkill -f talkies-overlay-gtk
~/talkies/linux/talkies-overlay-gtk &
```

### Recording processes instantly (blank audio)
**Symptoms**: Daemon shows `[BLANK_AUDIO]` immediately after pressing hotkey

**Cause**: State race condition (should be fixed in latest version)

**Verify fix**:
```bash
# Check toggle script doesn't reset state prematurely
grep -A5 'echo "processing"' ~/.config/hypr/scripts/talkies-toggle.sh
# Should NOT see: echo "idle" > "$STATE_FILE"
```

**If broken, update toggle script**:
```bash
cd ~/talkies/linux
git pull  # Get latest fix
# Or manually remove lines that reset state to "idle"
```

### Waveform doesn't animate
**Current limitation**: Waveform data is random values (placeholder)

**Future improvement**: Read actual audio levels from PulseAudio:
```bash
# Manual test of real audio levels:
pactl subscribe | grep --line-buffered "on source" &
pactl list sources | grep -A10 "Name: alsa_input"
```

### Hotkey doesn't work
**Check Hyprland config**:
```bash
grep talkies-toggle ~/.config/hypr/hyprland.conf
# Should show: bind = SUPER_ALT, T, exec, bash ~/.config/hypr/scripts/talkies-toggle.sh
```

**Reload Hyprland config**:
```
Super+Shift+R  (or hyprctl reload)
```

## File Locations Reference

| Component | Path |
|-----------|------|
| Daemon binary | `~/talkies/linux/zig-out/bin/talkies` |
| Toggle script | `~/.config/hypr/scripts/talkies-toggle.sh` |
| AGS widget | `~/.config/ags/widgets/talkies.js` |
| GTK overlay | `~/talkies/linux/talkies-overlay-gtk` |
| State file | `/tmp/talkies-state` |
| Waveform data | `/tmp/talkies-waveform` |
| Recording | `/tmp/talkies-recording.wav` |

## Performance Notes

- **Daemon CPU**: <1% idle, ~5-10% during transcription
- **Overlay CPU**: <1% (polls state file at 50ms = 20 FPS)
- **Memory**:
  - Daemon: ~50MB (whisper model loaded)
  - AGS widget: Negligible (part of AGS process)
  - GTK overlay: ~30MB (separate process)
- **Disk I/O**: Minimal (state files are <1KB)

## Customization

### Change Waveform Bar Count
Edit both AGS and GTK overlay:
```javascript
// AGS: ~/.config/ags/widgets/talkies.js
const WAVEFORM_BARS = 60;  // Default: 40
```

```python
# GTK: talkies-overlay-gtk
WAVEFORM_BARS = 60  # Default: 40
```

Also update toggle script:
```bash
# ~/.config/hypr/scripts/talkies-toggle.sh
for i in {1..60}; do echo "0"; done > "$WAVEFORM_FILE"
```

### Change Overlay Position
**AGS**:
```javascript
anchor: ["top"],        // Options: top, bottom, left, right
margins: [20, 0, 0, 0], // [top, right, bottom, left]
```

**GTK**: Window is auto-centered by compositor (no control in standalone mode)

### Change Colors
**AGS**:
```javascript
background: rgba(30, 30, 46, 0.95);  // Catppuccin Mocha base
border: 2px solid #cba6f7;           // Mauve
```

**GTK**:
```python
css_provider.load_from_data(b"""
    window {
        background: rgba(30, 30, 46, 0.95);
        border: 2px solid #cba6f7;
    }
""")
```

## Future Improvements

- [ ] Real-time audio level monitoring (replace random waveform)
- [ ] WebSocket IPC option (more efficient than file polling)
- [ ] Gradient waveform colors based on volume
- [ ] Configurable themes (Catppuccin variants, Nord, etc.)
- [ ] Error state visualization (red border on transcription failure)
- [ ] Pause/resume recording functionality
- [ ] Voice activity detection (auto-stop on silence)
