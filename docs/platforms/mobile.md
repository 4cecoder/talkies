# Mobile

For model setup and offline first-run checks, see the [first-run and troubleshooting guide](first-run-and-troubleshooting.md).

## Android (primary): native Kotlin and local Whisper

Talkies Android is built natively in [`mobile/android/`](../../mobile/android/), using Kotlin and Jetpack Compose. Stable transcript and cleanup contracts live in the JVM-only `:core` module; the separate Android `:inference` library owns verified model stores, JNI, whisper.cpp, llama.cpp, and local inference. The `:app` module owns Compose UI, microphone capture, and input-method lifecycle. It records 16 kHz mono audio in memory for at most five minutes per dictation, runs the downloaded Whisper tiny model through JNI, and presents an editable transcript with explicit copy feedback. At the recording limit, it transcribes the captured audio automatically. It does not use Android's vendor `SpeechRecognizer` or send audio to a recognition service.

The user explicitly downloads Whisper tiny before dictating. Optional cleanup is a separate, opt-in S1-mini download (484,219,808 bytes, about 462 MiB). Both models are revision-pinned and SHA-256 verified; the S1-mini Apache 2.0 `LICENSE` and `NOTICE` are stored alongside its weights. HTTPS is used only for a model download the user starts. Whisper and S1-mini then run on the device with CPU inference and no service fallback. Cleanup offers casual, semi-casual, balanced, semi-formal, and formal tone choices, plus prose or list formatting and general or email context. Balanced maps to the model's trained semi-formal prompt value. S1-mini stays loaded in the app process after its first use and is unloaded before deletion. The user can remove either model separately.

Talkies also provides a native Kotlin input method for direct dictation into the focused field in other apps. First download Whisper and grant microphone permission in Talkies, then use **Enable keyboard** in the app screen and enable Talkies voice typing in Android system settings. Use the system keyboard picker to select it. The keyboard records only while its Record control is active, applies the same optional local S1-mini settings, and commits the result into the current text field. It does not retain transcript history. Some secure or app-restricted fields may not allow third-party keyboard input. Leaving the keyboard while recognition is in progress prevents a delayed insertion into a later field.

Persistent transcript history and background dictation are not implemented on Android. Android supports API 28 and newer, including Fire OS 7 tablets (Android 9/API 28) and Fire OS 8 (Android 11/API 30). The app keeps target API 35 for current Android behavior; its minimum API supports Fire OS 7 and newer. Android CI pre-provisions both models, disables Wi-Fi and mobile data, enables airplane mode, then verifies actual Whisper recognition and S1-mini cleanup on an API 28 emulator, the lowest supported Fire tablet API baseline. See [Amazon's Fire OS 7](https://developer.amazon.com/docs/fire-tablets/fire-os-7.html) and [Fire OS 8](https://developer.amazon.com/docs/fire-tablets/fire-os-8.html) guidance for OS-to-API mapping.

Build and run the available tests:

```sh
# From the repository root, fetch the pinned native inference dependency.
git submodule update --init --recursive
cd mobile/android
./gradlew assembleDebug :core:test :inference:testDebugUnitTest :app:testDebugUnitTest
./gradlew assembleRelease :inference:testReleaseUnitTest :app:testReleaseUnitTest
```

Requires JDK 17, Android SDK API 36, CMake 3.31.6, and NDK 27.2. Android runtime support starts at API 28. Android CI builds and tests both debug and release variants, checks that the APKs contain both native runtimes and their license notices but omit model weights, and uploads the tested debug APK as a seven-day artifact. Core JVM tests cover transcript spacing, bounded PCM behavior, and the shared cleanup prompt/output contract. Inference module tests cover pinned model integrity and verified installation. API 28 emulator acceptance verifies real Whisper transcription and S1-mini transcript cleanup with external networking disabled. The app includes the whisper.cpp and llama.cpp MIT license notices and retains S1-mini's upstream Apache 2.0 files beside its separately downloaded weights.

## Deprecated Flutter prototype

The former Flutter/Dart prototype is preserved in [`archive/flutter-prototype/`](../../archive/flutter-prototype/README.md)
for historical reference. It is not built, tested, or distributed, and it is not an iOS release
target. Do not use its setup notes to build the supported Android app; use the native Kotlin project
in [`mobile/android/`](../../mobile/android/) instead.
