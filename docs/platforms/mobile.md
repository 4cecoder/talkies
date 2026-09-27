# Mobile

For model setup and offline first-run checks, see the [first-run and troubleshooting guide](first-run-and-troubleshooting.md).

## Android (primary): native Kotlin and local Whisper

Talkies Android is built natively in [`mobile/android/`](../../mobile/android/), using Kotlin, Jetpack Compose, and the pinned whisper.cpp CPU runtime. It records 16 kHz mono audio in memory for at most five minutes per dictation, runs the downloaded Whisper tiny model through JNI, and presents an editable transcript with explicit copy feedback. At the recording limit, it transcribes the captured audio automatically. It does not use Android's vendor `SpeechRecognizer` or send audio to a recognition service.

The user explicitly downloads Whisper tiny before dictating. Optional cleanup is a separate, opt-in S1-mini download (484,219,808 bytes, about 462 MiB). Both models are revision-pinned and SHA-256 verified; the S1-mini Apache 2.0 `LICENSE` and `NOTICE` are stored alongside its weights. HTTPS is used only for a model download the user starts. Whisper and S1-mini then run on the device with CPU inference and no service fallback. Cleanup offers casual, semi-casual, balanced, semi-formal, and formal tone choices, plus prose or list formatting and general or email context. Balanced maps to the model's trained semi-formal prompt value. S1-mini stays loaded in the app process after its first use and is unloaded before deletion. The user can remove either model separately.

Persistent transcript history and background dictation are not implemented on Android. Android CI pre-provisions both models, disables Wi-Fi and mobile data, enables airplane mode, then verifies actual Whisper recognition and S1-mini cleanup on an API 35 emulator.

Build and run the available tests:

```sh
# From the repository root, fetch the pinned native inference dependency.
git submodule update --init --recursive
cd mobile/android
./gradlew assembleDebug
./gradlew testDebugUnitTest
./gradlew assembleRelease testReleaseUnitTest
```

Requires JDK 17, Android SDK API 36, CMake 3.31.6, and NDK 27.2. Android runtime support starts at API 31. Android CI builds and tests both debug and release variants, checks that the APKs contain both native runtimes and their license notices but omit model weights, and uploads the tested debug APK as a seven-day artifact. JVM tests cover model integrity and the shared cleanup prompt/output contract. API 35 emulator acceptance verifies real Whisper transcription and S1-mini transcript cleanup with external networking disabled. The app includes the whisper.cpp and llama.cpp MIT license notices and retains S1-mini's upstream Apache 2.0 files beside its separately downloaded weights.

## Flutter prototype (legacy)

The old Flutter prototype remains in `mobile/lib/`, `mobile/ios/`, and `mobile/pubspec.yaml` as historical reference. Android no longer uses Flutter. The Flutter app is not actively developed, built, or distributed; its features and setup instructions below are not a statement of current Android functionality.
