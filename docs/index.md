# Talkies

Local voice in. Clean text out. Your audio stays on your device.

Talkies is a free, open-source dictation app for macOS, Windows, and Linux. The product direction is a small, friendly desktop tool with fast global shortcuts, local speech recognition, optional local transcript cleanup, and text insertion into the app you are already using.

## Start here

| I want to… | Read |
|---|---|
| Understand what Talkies is becoming | [Product vision](product/vision.md) |
| See what exists and what is missing | [Feature gap analysis](product/feature-gap-analysis.md) |
| Build the macOS app | [macOS build guide](platforms/macos.md) |
| Build Windows / Linux | [Platform guides](README.md#platform-build-guides) |
| Build the website | [Website guide](platforms/website.md) |
| Understand the macOS package boundaries | [Volatility split](architecture/macos-volatility-split.md) |
| Work on CI, tests, and installers | [Quality and distribution](engineering/quality-and-distribution.md) |
| Find open engineering work | [Roadmap](ROADMAP.md) |

## Product promises

- **Free and open source under MIT.** No subscription or paid tier; see the root [LICENSE](../LICENSE).
- **Offline by default.** Recording, transcription, cleanup, and insertion use on-device code and models. Internet access is limited to optional model downloads and app updates; local inference servers may use loopback connections on this device. After setup, dictation works without external network access.
- **Private by design.** Audio and transcripts are not sent to hosted inference services.
- **One product across desktop platforms.** macOS, Windows, and Linux get the same dictation workflow, with native platform interfaces.

## Current state

The macOS package builds with Swift 6.3.3. Speech recognition uses WhisperKit. Its `TalkiesCore` target contains stable transcript and cleanup contracts; the volatile `TalkiesInference` target contains a llama.cpp adapter for the pinned S1-mini GGUF. S1-mini cleanup is opt-in in General settings, downloads weights on first use, and runs inference on the CPU. After the model is available, transcript cleanup works offline and transcript text never leaves the device. Windows and Linux have separate native implementations and do not yet share this cleanup behavior or feature set.

## Architecture map

```text
Microphone → local speech recognizer → optional local text cleanup → paste/type → discard temporary audio
```

See the [gap analysis](product/feature-gap-analysis.md) for product scope and [quality plan](engineering/quality-and-distribution.md) for build and release gates.
