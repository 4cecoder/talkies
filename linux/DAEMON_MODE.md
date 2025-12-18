# Talkies Linux Daemon Mode

## Overview

Daemon mode allows you to run Talkies as a background service that listens for Right Alt key presses to start/stop voice recording and transcription.

## Quick Start

```bash
# Start the daemon
./talkies daemon

# In another terminal or continue using your computer normally
# Press Right Alt to start recording
# Release Right Alt to stop and transcribe
```

## How It Works

1. **Start Daemon**: `talkies daemon` loads the whisper model and starts listening for hotkeys
2. **Press Right Alt**: Starts recording audio from your configured microphone
3. **Release Right Alt**: Stops recording, transcribes using GPU-accelerated whisper, and pastes/copies the text
4. **Continue**: Keep using your computer normally, press Right Alt again when needed

## Configuration

The daemon respects all settings in `~/.config/talkies/config.toml`:

```toml
[audio]
device = "alsa_input.usb-SunplusIT_Inc_Nisheng_M3_W20221116-02.mono-fallback"

[transcription]
model = "small"
language = "en"
threads = 4

[output]
auto_paste = true      # If true: inserts text at cursor, if false: copies to clipboard
export_format = "txt"
```

## Visual Feedback

The daemon provides emoji-based status updates in the terminal:

- 🔴 **Recording started...** - Right Alt pressed, recording audio
- ⏹️  **Recording stopped (300ms hold)** - Right Alt released
- ⚙️  **Transcribing...** - Processing audio with whisper
- 📝 **Transcription: [text]** - Shows the transcribed text
- ✨ **Inserting text at cursor...** - Pasting into active window (if auto_paste = true)
- 📋 **Copying to clipboard...** - Saved to clipboard (if auto_paste = false)
- ✅ **Done!** - Ready for next recording

## Tap vs Hold Detection

The daemon detects the difference between a quick tap and a hold:

- **Tap** (< 300ms): Quick recording for short commands
- **Hold** (≥ 300ms): Longer recording, shows duration in milliseconds

## Performance

- **Model Loading**: Happens once at daemon startup (~2-3 seconds)
- **Recording**: Real-time audio capture with PulseAudio
- **Transcription**: GPU-accelerated (Vulkan/CUDA) for fastest results
- **Text Insertion**: Uses xdotool for seamless paste simulation

## Requirements

- X11 display server (Wayland support coming soon)
- Right Alt key available (not bound to other system hotkeys)
- PulseAudio or compatible audio system
- GPU with Vulkan support (optional, falls back to CPU)

## Troubleshooting

### Hotkey Not Working

If Right Alt doesn't trigger recording:

1. **Check X11**: Daemon requires X11 (not Wayland yet)
   ```bash
   echo $XDG_SESSION_TYPE  # Should show "x11"
   ```

2. **Check Key Binding**: Make sure Right Alt isn't bound to another application
   ```bash
   xmodmap -pke | grep Alt_R
   ```

3. **Permissions**: Daemon needs permission to grab global hotkeys

### Recording Empty/Silent

Check your audio device configuration:

```bash
# List available input sources
pactl list sources short

# Update config with correct device
vim ~/.config/talkies/config.toml
```

### GPU Not Detected

Check whisper.cpp GPU support:

```bash
# Check for Vulkan
vulkaninfo | grep deviceName

# If no GPU, whisper will fall back to CPU (slower but works)
```

## Running in Background

To run daemon in the background with systemd:

```bash
# Create user service
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/talkies.service <<EOF
[Unit]
Description=Talkies Voice Transcription Daemon
After=graphical.target

[Service]
Type=simple
ExecStart=/path/to/talkies daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Enable and start
systemctl --user enable talkies.service
systemctl --user start talkies.service

# Check status
systemctl --user status talkies.service

# View logs
journalctl --user -u talkies.service -f
```

## Alternative: tmux/screen

For a simpler approach, run in a detached terminal session:

```bash
# Using tmux
tmux new-session -d -s talkies 'cd ~/talkies/linux && ./talkies daemon'

# Check status
tmux attach -t talkies

# Detach: Ctrl+B then D

# Using screen
screen -dmS talkies bash -c 'cd ~/talkies/linux && ./talkies daemon'

# Check status
screen -r talkies

# Detach: Ctrl+A then D
```

## Exit Daemon

To stop the daemon:

1. Focus the terminal running `talkies daemon`
2. Press **Ctrl+C**

If running as systemd service:
```bash
systemctl --user stop talkies.service
```

## Next Steps

- Try different whisper models (`tiny`, `base`, `small`, `medium`, `large`)
- Adjust `auto_paste` setting based on your workflow
- Configure different audio devices for specific use cases
- Set up systemd service for autostart on login
