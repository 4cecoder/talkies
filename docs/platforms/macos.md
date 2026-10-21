# Talkies Swift macOS App

A native Swift macOS dictation app using Phonon-2 on Core ML for English speech recognition, WhisperKit as the multilingual fallback, and optional S1-mini cleanup through llama.cpp.

## Features

### 🎤 Real-Time Transcription
- Live voice-to-text using Phonon-2 (English, default) with an on-device WhisperKit fallback
- Optional S1-mini transcript cleanup using the local Q4_K_M GGUF model
- CPU-only cleanup inference through llama.cpp
- Voice Activity Detection (VAD) for efficient processing
- Real-time audio level monitoring

### 🎨 Modern SwiftUI Interface
- Clean, professional design inspired by SuperWhisper
- Native macOS controls and interactions
- Smooth animations and transitions
- Dark mode support
- Responsive layout for different screen sizes

### 📊 Live Statistics
- Word count and words-per-minute tracking
- Segment counting
- Recording duration
- Real-time audio visualization

### 💾 Export Options
- WebVTT (.vtt) format for video subtitles
- SubRip (.srt) format for compatibility
- Plain text (.txt) for easy sharing
- Native macOS file picker

### ⚙️ Customizable Settings
- Multiple Whisper model sizes (tiny to large-v3-turbo)
- Language selection with auto-detection
- Audio quality settings
- Hallucination filter
- Export preferences

## Requirements

- macOS 15+
- Apple Silicon recommended for WhisperKit performance
- Swift 6.3 or newer
- Microphone access permission

## Quick Start

```bash
./run.sh          # Build and run
./run.sh build    # Debug build only
./run.sh release  # Release build
./run.sh clean    # Clean build directory
```

## Manual Build

Use Swift 6.3 or newer from your active toolchain:

```bash
swift --version
swift build
swift run Talkies
```

The package manifest requires Swift tools 6.3. CI and release builds use Swift 6.3.3.

## Install and update from a release

Verify the macOS DMG against `SHA256SUMS`, open it, and drag `Talkies.app` to
`/Applications`. In **Settings → General → About**, choose **Check for Updates** to compare the
installed version with the latest stable release, then **Download Update** to open its release page.
For a manual update, quit Talkies, open the newer DMG, and replace the existing
`/Applications/Talkies.app` with the new copy. Model weights and preferences are stored outside the
app bundle, so replacing the app does not delete them. ZIP downloads contain the same app bundle if
you prefer to install without mounting a DMG.

## Local crash diagnostics

Talkies may write a small local exception report containing only the exception
name, reason, timestamp, and stack trace. Reports are stored under
`~/Library/Application Support/Talkies/Diagnostics/`, limited to 32 KiB each,
and rotated to keep at most five reports. They are never uploaded. To delete
them, quit Talkies and remove that `Diagnostics` folder in Finder or with:

```sh
rm -rf "$HOME/Library/Application Support/Talkies/Diagnostics"
```

## Transcript history

Each finished dictation (the final text after cleanup) is saved locally to
`~/Library/Application Support/Talkies/history.sqlite` (owner-only, mode `0600`) when
Settings → General → **Save transcript history** is on, which is the default. Entries never
expire automatically. Turning the setting off stops saving new transcripts but keeps existing
ones. Open history from the dictation panel to search, copy, or delete entries; **Clear All**
there or **Clear History…** in Settings deletes every row and compacts the file. Transcript
text is never written to logs.

The file uses the cross-platform `transcripts` schema (`PRAGMA user_version = 1`, WAL):
`id`, `uuid` (random lowercase UUIDv4), `created_at` (Unix epoch milliseconds, UTC), `text`,
`raw_text` (recognizer output, `NULL` when identical to `text`), `duration_ms`, `runtime`
(`phonon` or `whisper`), and `language` (`en` for Phonon-2, `NULL` when unknown). The store is
`TranscriptHistoryStore` in `TalkiesCore`, built on the system SQLite library. Search uses
SQLite `LIKE`, which ignores case for ASCII letters only.

## Usage

### First Time Setup

1. Launch Talkies from your Applications folder
2. Grant microphone permission when prompted
3. Configure your preferred settings in the Settings tab

### Recording and Transcription

1. **Start Recording**: Click the red record button or press the global shortcut
2. **Speak Clearly**: The app will transcribe your speech in real-time
3. **Monitor Progress**: Watch the live transcript and statistics
4. **Stop Recording**: Click the stop button when finished
5. **Export**: Save your transcript in your preferred format

### Keyboard Shortcuts

- `⌘ + R`: Start/Stop recording
- `⌘ + E`: Export transcript
- `⌘ + ,`: Open settings
- `⌘ + W`: Close window (keep recording in background)

## Architecture

### Swift Components

- **TalkiesApp.swift**: Main app entry point
- **ContentView.swift**: Primary interface with sidebar navigation
- **AudioRecorder.swift**: AVFoundation-based audio recording
- **TranscriptionService.swift**: transcription pipeline over the speech-runtime chain
- **TalkiesInference**: speech-runtime chain (`SpeechRecognizerChain`), Phonon-2 and WhisperKit adapters, S1-mini model storage and llama.cpp CPU adapter
- **TalkiesCore agent contracts**: `AgentConnector`, the agent-mode intent grammar (`AgentIntentParser`), name matching, and the safety gate, tested against `tests/fixtures/intents/`
- **TalkiesConnectors**: the cmux connector, which drives the cmux CLI and is tested against recorded JSON in `tests/fixtures/agents/`
- **AgentModeController.swift / AgentPanelView.swift**: agent-mode HUD, target picker, cancel window, and spoken replies
- **RecordingView.swift**: Live recording interface
- **TranscriptView.swift**: Transcript viewing and editing
- **SettingsView.swift**: App configuration

## Performance

Speech recognition and transcript cleanup run on-device. S1-mini cleanup uses the CPU and its model is downloaded on first use; after download, cleanup works offline.

## Troubleshooting

See the shared [first-run and troubleshooting guide](first-run-and-troubleshooting.md) for model setup, Accessibility approval, offline checks, and cache recovery.

### Microphone Permission
If microphone access is denied:
1. Open System Settings > Privacy & Security > Microphone
2. Enable Talkies in the list
3. Restart the app

### Agent mode (cmux)

Agent mode lets you talk to coding agents running in [cmux](https://cmux.com) without leaving the
app you're in. It is off by default and uses its own key, so the dictation key keeps its current
behavior and never runs commands. Command-shaped text dictated with the dictation key, such as
"approve", is inserted as typed.

1. Open Settings → **Agents**, turn on **Enable agent mode**, and choose an **Agent key**. No key is
   set until you choose one, and it can't be the dictation key.
2. Let Talkies reach cmux's socket. By default cmux accepts commands only from programs started
   inside cmux, and Talkies shows "cmux only accepts commands from programs started inside cmux"
   until you change that. In cmux, open Settings → Automation and set **Socket Control Mode** to
   **Password mode**, then enter the same password in Talkies Settings → Agents. Talkies stores it in
   the Keychain and passes it to the cmux CLI only through `CMUX_SOCKET_PASSWORD`, never as an
   argument. **Automation mode** also works and needs no password. Use **Test Connection** to check;
   it only lists agents.
3. Hold the agent key while you speak, then release it. Start with an agent's name, or pick a target
   from the HUD's target menu or the menu bar's **Agent Target** submenu. Agent mode is hold-to-talk
   only. Nothing happens while you press the key: the HUD appears and the microphone opens only
   after the key has been held alone for about a third of a second, so start speaking once the HUD
   says it is listening. A tap, or a press that becomes a shortcut (another key, another modifier,
   or a mouse click during the hold, such as ⌘V or ⌘-click), is dropped without showing, closing,
   or recording anything.

What you can say:

| You say | What happens |
|---|---|
| "Atlas, run the tests" | Shows `To Atlas: "Run the tests"` with a two-second cancel window, then delivers it with `cmux agent message`. Press Esc or **Cancel** to stop it. |
| "What's Atlas doing?", "Atlas, status", "agent 2 status" | Reads `surface.input_state` and shows and speaks a short status line. |
| "List agents" | Lists cmux agents in order; the numbers work in "agent 2". |
| "Atlas, read the last message" | Shows and speaks the agent's latest cmux notification, or recent screen text. |
| "Show Atlas" | After the cancel window, selects that workspace and surface in cmux. |
| "Approve", "deny", "stop", "remember …" | Refused for now with an explanation; answer permission prompts in cmux. |

How targets work:

- Talkies lists only surfaces cmux detects as agents. An agent alone in its workspace is named after
  the workspace; agents that share a workspace are named after their tab.
- Names are matched by spelling distance and a phonetic key, so "at last" finds Atlas. If two agents
  match about equally well, Talkies asks "Which agent?" and never guesses.
- A prompt without a name goes to the selected target. Saying a name also selects that agent.
- Talkies refuses to deliver when the target has a draft or a question open, or isn't running an
  agent, and says why. It never types into the terminal and never passes `--force`.
- cmux is called with argument arrays through `Process`, never a shell, and prompt text goes to
  `cmux agent message <surface> -` on standard input.

Agent-mode text is parsed exactly as recognized. S1-mini cleanup and the Ollama and LM Studio
plugins apply only to dictation, so a rewrite can't change what is sent or which command runs.
Each recording keeps its own mode and insertion target from the moment its key is pressed, so a
dictation that is still transcribing is inserted where you started it even if you press the agent
key in the meantime.

If you press the agent key or start dictating while a send is counting down, the send is held. It
then waits for an explicit **Send now**, **Cancel**, or a spoken "send" or "cancel", and it is
never sent automatically. A spoken "send" that names a different agent doesn't release it.

Replies are spoken with the on-device `AVSpeechSynthesizer`; turn off **Speak status replies** to
see them only in the HUD. Agent-mode utterances are saved to transcript history like other
dictation, following the **Save transcript history** setting. They are stored as recognized,
since agent mode skips cleanup.

Agent mode uses no network connection. The cmux CLI is found at
`/Applications/cmux.app/Contents/Resources/bin/cmux`, `~/Applications/cmux.app/…`, or on `PATH`.
To run the read-only connector smoke test against a running cmux (from a cmux terminal or with
external clients allowed), use:

```sh
cd mac && TALKIES_CMUX_SMOKE=1 swift test --filter CmuxLiveSmokeTests
```

### Speech engines

Settings → General → **Speech Engine** chooses between:

- **Phonon-2 (English), Whisper fallback** (default). Talkies runs [Phonon-2](https://huggingface.co/FermionResearch/Phonon-2-CoreML)
  through Fermion Research's [`phonon-coreml`](https://github.com/fermionresearch/phonon-coreml) Swift package (pinned to 1.1.2).
  If Phonon-2 is missing, fails to load, or fails a transcription, the same recording is transcribed with WhisperKit.
- **Whisper (multilingual)**: WhisperKit `openai_whisper-base` only. Use this for languages other than English.

The first Phonon-2 use downloads about 345 MB from a pinned Hugging Face revision into
`~/Library/Application Support/Talkies/Models/Phonon-2-CoreML-<revision>/`, with every file checked against
its size and SHA-256 from the repository's `SHA256SUMS`. macOS then compiles the encoder for the Neural Engine
once, which took about five minutes on an M-series test Mac. The compiled copy is cached in
`~/Library/Caches/phonon-coreml/`. While that one-time preparation runs, Talkies uses an already-installed
Whisper model so dictation isn't blocked. Later loads take a few seconds.

Phonon-2 has no vocabulary prompt, so personal vocabulary affects only the Whisper path and S1-mini cleanup.
Phonon-2 weights are CC BY 4.0 (Fermion Research, derived from NVIDIA Parakeet TDT 0.6B v3). The license and
NOTICE files are downloaded next to the weights. `phonon-coreml` is Apache 2.0 and links a prebuilt static
TDT decoder library (`PhononTDT.xcframework`) supplied by the package.

To run the offline Phonon-2 acceptance test against a provisioned bundle:

```sh
cd mac && TALKIES_PHONON_MODEL_DIR=/path/to/Phonon-2-CoreML swift test --filter PhononAcceptanceTests
```

### S1-mini download issues
S1-mini requires a one-time model download. Connect to the network, retry cleanup, and then the app can use the verified local model offline. If cleanup still fails, Talkies inserts the raw WhisperKit transcript.

### Performance Issues
For better performance, select a smaller WhisperKit speech model and leave enough memory for the local speech model and S1-mini's CPU context.

## Development

### Building from Source

```bash
./run.sh build    # Debug build
./run.sh          # Build and run
```

### Project Structure
```
mac/
├── Package.swift              # Swift package configuration
├── run.sh                     # Build/run helper script
├── Sources/
│   └── Talkies/
│       ├── TalkiesApp.swift
│       ├── ContentView.swift
│       ├── AudioRecorder.swift
│       ├── TranscriptionService.swift
│       ├── RecordingView.swift
│       ├── TranscriptView.swift
│       └── SettingsView.swift
└── README.md
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and feature requests:
- Create an issue on GitHub
- Check the troubleshooting guide
- Review the documentation

---

**Talkies** - Local voice dictation with optional offline transcript cleanup.
