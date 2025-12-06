# Talkies Windows Port (C# GUI)

This doc explains how to rebuild the Talkies real-time GUI in C# for Windows while reusing the existing Python speech pipeline.

## What the current app does
- Core loop lives in `src/whisper_cli/realtime.py`: captures mic audio with `sounddevice`, optional VAD (`webrtcvad`), transcribes every ~2s via MLX Whisper (Apple only) or faster-whisper, filters hallucinations, and builds WebVTT segments.
- The PyQt6 GUI in `src/whisper_cli/gui.py` starts/stops the `RealtimeVTTStream`, subscribes to `on_segment` callbacks, updates stats (segments, words, WPM), and saves `get_vtt()` output to disk.
- CLI entry is `src/whisper_cli/cli.py` (`whisper-cli live --gui`), which passes model/language/cpu flags into the GUI/stream.

## Windows considerations
- MLX is macOS-only; on Windows the backend is faster-whisper (CPU by default, or CUDA if available). Set `[whisper] device = "cuda"` and `compute_type = "float16"` in `~/.whisper-cli.toml` when using NVIDIA.
- `sounddevice` uses PortAudio; install a 64-bit Python and ensure audio input works (WASAPI). VAD requires `webrtcvad` wheels; use Python 3.10+ to get prebuilt wheels on Windows.
- Install deps: `python -m pip install --upgrade pip uv` then `uv venv && uv pip install -e .` from the repo root. This installs faster-whisper, sounddevice, webrtcvad, etc.
- Expect slightly higher latency on CPU; prefer GPU if present or use smaller models (`tiny/base`) for responsiveness.

## Target UX parity
- Left rail: start/stop toggle, save/export VTT, clear transcript, model + language pickers, toggles for VAD and hallucination filter, backend indicator (GPU/CPU), and elapsed timer.
- Right pane: scrolling list of segments with timestamps, auto-scroll to newest, empty-state messaging, simple stats (segments, words, WPM).
- Behavior: disable Save while recording; on stop enable Save; prompt on close while recording.

## What the Swift app does (to mirror in C#)
- Entry (`TalkiesApp.swift`): menu bar item, floating non-activating window, settings window, global hotkey (Right Option) with dual modes (tap = toggle record, hold = push-to-talk), no focus stealing, auto-hide after actions.
- Recording (`AudioRecorder.swift`): AVAudioEngine capture to WAV, live audio level for waveform, duration timer, `onRecordingComplete(url)` callback.
- Transcription (`TranscriptionService.swift`): init WhisperKit (Apple-only) async; transcribe finished WAV; maintain segments, words, WPM; export VTT/SRT/TXT; `onTranscriptionComplete(text)` used to insert text or speak.
- UI (`DictationView.swift`, `ContentView.swift`): floating glassmorphic widget with status dot, waveform, recent transcript, and a larger tabbed window (Record/Transcript/Settings).
- Text insertion (`TextInserter.swift`): simulates typing via accessibility APIs; on macOS requires permissions. Plugins add optional LLM enhancement/TTS.

### Windows equivalents for the above
- Menu/float: WPF/WinUI window set to top-most; optional tray icon/context menu; avoid focus stealing when showing the small panel.
- Hotkey: `RegisterHotKey` for Right Alt (or user-selectable); measure press duration to choose push-to-talk vs toggle just like `pushToTalkThreshold`.
- Recording: NAudio (WASAPI) to capture mono PCM to temp WAV; surface level and duration; raise `OnRecordingComplete(string path)` event.
- Transcription: call the Python IPC worker (below) or a C# wrapper over faster-whisper; rebuild segments, words, WPM; keep exports in VTT/SRT/TXT.
- UI: two-pane dark layout; status pill, waveform (level-driven), recent segments list, export button, model/lang dropdowns, VAD/filter toggles; prompt on close while recording.
- Text insertion: use `SendInput` (keystroke injection) and a clipboard fallback; no macOS accessibility prompt but handle focus timing (small delay before typing).

## Recommended architecture for the C# port
Keep Python for audio + transcription and wrap it with a tiny IPC layer. Build the UI in WPF/WinUI/WinForms and talk to a long-lived Python worker over stdio (JSONL) or named pipes.

### Minimal Python worker (JSONL over stdio)
Create a small Python entry point that mirrors the GUI thread behavior:

```python
# run with: python -m whisper_cli.bridge
import json, sys, threading, time
from whisper_cli.realtime import RealtimeVTTStream

streamer = None

def start(opts):
    global streamer
    streamer = RealtimeVTTStream(
        model=opts.get("model", "medium"),
        language=opts.get("language"),
        use_mlx=False,           # Windows
        vad_enabled=opts.get("vad", True),
        config=opts.get("config", {})
    )
    start_time = time.time()

    def on_seg(seg):
        sys.stdout.write(json.dumps({
            "type": "segment",
            "timestamp": seg._format_timestamp(seg.start),
            "start": seg.start,
            "end": seg.end,
            "text": seg.text,
            "wpm": (len(seg.text.split()) / max(time.time() - start_time, 1)) * 60,
        }) + "\n"); sys.stdout.flush()

    streamer.on_segment(on_seg)
    streamer.start()
    sys.stdout.write(json.dumps({"type": "status", "value": "recording"}) + "\n"); sys.stdout.flush()

def stop():
    if streamer:
        streamer.stop()
        sys.stdout.write(json.dumps({"type": "vtt", "value": streamer.get_vtt()}) + "\n"); sys.stdout.flush()

for line in sys.stdin:
    msg = json.loads(line)
    if msg["cmd"] == "start":
        threading.Thread(target=start, args=(msg,), daemon=True).start()
    elif msg["cmd"] == "stop":
        stop()
    elif msg["cmd"] == "ping":
        sys.stdout.write(json.dumps({"type": "pong"}) + "\n"); sys.stdout.flush()
```

### C# side flow
- Launch the worker via `ProcessStartInfo` (`python`, `-m whisper_cli.bridge`), redirect stdio, and send JSON commands.
- On “Start Recording”: send `{"cmd":"start","model":"base","language":"en","vad":true}`; store start timestamp in C# for timer display.
- Read stdout lines, parse JSON, and update UI:
  - `segment`: append to list, update counts/WPM, scroll to bottom.
  - `status`: update backend indicator.
  - `vtt`: cache the string for Save/Export; write to `.vtt` on disk.
- On “Stop”: send `{"cmd":"stop"}`; after receiving `vtt`, enable Save.
- On “Clear”: clear local segment list and stats; no backend call needed.
- On close while recording: send `stop` then exit the process.

### Mapping PyQt behaviors to C#
- Timer: 1s `DispatcherTimer` updates `mm:ss`.
- Stats: segment count = list length; words = sum of `text.Split().Length`; WPM can be recomputed in C# using start time.
- Styling: dark theme with two-pane layout; use gradients/blur if desired, but keep focus on readability and large controls.

## Validation checklist
- Backend: `python -m whisper_cli.cli system --recommend` prints without errors; `whisper-cli live --duration 5 --model tiny` produces VTT on Windows.
- IPC: starting/stopping from C# produces segment events and final VTT; no deadlocks when process exits.
- Save: saved `.vtt` opens in a text editor and matches `WEBVTT` format.
- Devices: enumerate mics via `whisper-cli record --list-devices` and surface them in the C# UI dropdown if needed.

## Next steps
1) Add the Python bridge module (or reuse an equivalent IPC script) to the repo.  
2) Scaffold the C# UI (WPF recommended) and wire start/stop/save/clear to the IPC contract above.  
3) Add logging around process launch/stdout parsing for supportability.  
4) Exercise tiny/base models on Windows CPU; verify CUDA path if you target NVIDIA GPUs.
