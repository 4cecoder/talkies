# Talkies for macOS Monterey

This is a separate, experimental Talkies build for macOS 12.7.6. It keeps the
current macOS 15+ app and its release dependencies unchanged. This preview uses
the repository's pinned whisper.cpp and llama.cpp submodules. Apple silicon uses
Metal with CPU fallback; Intel Macs use CPU and a smaller Whisper model. Model
files are fetched on first use, verified by SHA-256, and stored outside the app
bundle.

## What the preview does

- Records microphone audio and shows listening, transcription, cleanup, success,
  and error states in a small SwiftUI window.
- Transcribes locally with multilingual Whisper base on Apple silicon and the
  smaller multilingual Whisper tiny model on Intel Macs.
- Optionally polishes the transcript with local Superwhisper S1-mini. The model
  is downloaded only after enabling cleanup and completing a transcription.
- Keeps clipboard writes behind the explicit Copy button.
- Works without a network connection after the required models finish downloading.

This first preview is a focused Monterey compatibility build. It does not yet
include the current app's global activation shortcut, direct cursor insertion,
device/settings controls, export formats, or menu-bar controls. Use Copy to move
the transcript into another app while those integrations are being ported.

## Build

Initialize the inference submodules if they are not already present:

```sh
git submodule update --init --recursive mobile/android/third_party/whisper.cpp mobile/android/third_party/llama.cpp
```

Build a universal package for Intel and Apple silicon:

```sh
mac/Monterey/build.sh universal
mac/Monterey/package-zip.sh universal
```

Use `arm64` or `x86_64` for an architecture-specific package instead. The
universal package contains the app and native inference executables for both
architectures, but no models. Build with Xcode Command Line Tools, CMake, and
Swift 6.3 or newer. The app target is macOS 12.0; the build output must still be
tested on a real Monterey 12.7.6 Mac before calling it supported.

The ZIP and SHA-256 file are written to `mac/Monterey/dist/`. The app is ad-hoc
signed for archive integrity, not Developer ID signed or notarized. On the test
Mac, unzip it, Control-click Talkies Monterey, choose **Open**, and confirm the
first-launch prompt. Then grant microphone permission when macOS asks.

## First run and offline use

The Whisper base model download is about 142 MiB. Optional S1-mini cleanup
downloads another 462 MiB plus its license/notice files. Keep the Mac online
until each requested model is installed; Talkies verifies each model's size and
SHA-256 before using it. After that, disconnect from the network and confirm
that recording, transcription, and enabled cleanup still work.

Model cache: `~/Library/Application Support/Talkies-Monterey/Models/`.
Recordings are temporary and are removed after transcription completes.

## Tester feedback

Please report the Mac model and CPU family (Intel or Apple silicon), macOS
version, available memory, model download/inference timing, whether transcription
works offline after setup, and any crash report or visible error. Don't send
audio recordings or transcript text unless the speaker has agreed to share it.
