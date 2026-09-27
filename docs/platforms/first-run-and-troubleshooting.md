# First run and troubleshooting

Talkies downloads speech and cleanup models only when the app needs a model that is not already installed. Downloads use HTTPS and are checked against pinned size and SHA-256 values. Once the models you use are installed, recording, transcription, cleanup, and text insertion run locally. Keep the app online during the first model setup; after that, test offline by disconnecting the network and transcribing a short recording.

Models are separate from the app packages. Updating or reinstalling Talkies normally leaves models and settings in place. See the platform-specific sections below for storage locations and permissions.

## macOS

1. Open Talkies and grant microphone access when macOS asks.
2. Make a short recording while connected to the internet. WhisperKit prepares its selected local speech model on first use. The default model is `openai_whisper-base`.
3. To use cleanup, enable S1-mini in **Settings → General**. Its English model is downloaded the first time cleanup runs and takes about 462 MiB.
4. Grant Talkies access under **System Settings → Privacy & Security → Accessibility** when prompted so it can insert text into another app. If insertion is unavailable, use Talkies' explicit copy action and paste manually.
5. Disconnect the network and try another short dictation to confirm the models are ready offline.

WhisperKit stores model files below `~/Documents/huggingface/models/`. S1-mini and its license notices are stored below `~/Library/Application Support/Talkies/Models/`. Talkies preferences are in `~/.talkies/config.json`. To recover from an incomplete WhisperKit download, quit Talkies, remove only the affected model folder, and retry while online. To recover from an S1-mini download error, retry cleanup while online; Talkies validates the model before loading it and falls back to the raw transcript if cleanup fails.

If the microphone is blocked, open **System Settings → Privacy & Security → Microphone**, enable Talkies, then quit and reopen it. If macOS no longer recognizes Accessibility approval after replacing the app, remove the old Talkies entry from **Privacy & Security → Accessibility**, add the installed copy again, and relaunch it.

## Windows

1. Select a microphone and a Whisper model in Talkies.
2. While online, dictate once to download and verify the selected Whisper model.
3. If desired, enable S1-mini cleanup and let its roughly 462 MiB English model download.
4. Try insertion in a normal text field. If a target application blocks simulated typing, switch to that app and use Talkies' copy/export option instead.
5. Disconnect the network and repeat a short dictation.

Whisper models are stored in `%USERPROFILE%\.talkies\models`. Settings are in `%USERPROFILE%\.talkies\config.json`. S1-mini and its notices are stored under `%LOCALAPPDATA%\Talkies\Models`. An interrupted or invalid model download is rejected; retry the model download while online. The per-user installer preserves models and settings during updates and uninstall.

## Linux

1. Install the Debian package or unpack the portable archive and install its documented system dependencies.
2. Connect a microphone and check that Talkies can list it with `talkies audio-list`.
3. Download the selected Whisper model with `talkies models`, then start the daemon with `talkies daemon` (or use the documented quick command).
4. If S1-mini cleanup is enabled for your workflow, allow its first model setup to finish while online.
5. Cleanup is enabled by default in the Linux configuration. Its first use downloads the S1-mini model; disable `[cleanup].s1_cleanup_enabled` in the TOML config if you only want raw ASR. Disconnect the network and dictate a short phrase to confirm the local models are available.

By default, data is stored under `~/.local/share/talkies/`; `XDG_DATA_HOME` can change this base directory. Whisper weights are in its `models/` subdirectory. The pinned S1-mini model is stored in `models/s1-mini-<revision>/`. Configuration is under `~/.config/talkies/`, or `$XDG_CONFIG_HOME/talkies/` when configured. Model downloads are verified before use. If a model is missing or fails verification, reconnect and run the model setup again. For audio-device, X11, Wayland, and package dependencies, see the [Linux guide](linux.md) and its linked dependency notes.

## Android

1. Open the native Android app and explicitly download Whisper tiny. The download is about 74 MiB and is verified before use.
2. Grant microphone permission and make a short recording.
3. Optional S1-mini cleanup is a separate download of about 462 MiB; select it only if you want cleanup.
4. Turn on airplane mode and repeat a short dictation. Recognition and cleanup run locally after model setup.

Android stores both models in app-private storage under `files/models/`. The app can delete each model from its model controls. If a download is interrupted or rejected by integrity validation, reconnect and retry it. Clearing app storage or uninstalling Android Talkies removes its app-private models and settings.

## General checks

- Confirm there is enough free disk space for the selected models. Whisper model size varies; S1-mini requires about 462 MiB.
- Do not delete a model while Talkies is using it. Quit or stop inference first.
- First-run downloads need access to Hugging Face over HTTPS. Inference should not require an external connection once the model is present.
- If recognition returns no words, check the selected microphone and input level, shorten the test phrase, and verify the operating system's microphone permission.
- S1-mini is an English transcript post-processor, not a speech recognizer. If it fails, Talkies retains or uses the raw ASR transcript.
- Talkies does not upload audio or transcript text to a hosted inference service. Optional desktop Ollama and LM Studio adapters accept loopback endpoints only.

For platform-specific install and build instructions, start at the [platform guides](../README.md#platform-build-guides). Report reproducible failures in [GitHub Issues](https://github.com/4cecoder/talkies/issues) with the OS, Talkies version, model selected, and the failing step; do not attach private transcripts or recordings.
