# Mobile

## Android (primary): native Kotlin and local Whisper

Talkies Android is built natively in [`mobile/android/`](../../mobile/android/), using Kotlin, Jetpack Compose, and the pinned whisper.cpp CPU runtime. It records 16 kHz mono audio in memory for at most five minutes per dictation, runs the downloaded Whisper tiny model through JNI, and presents an editable transcript with explicit copy feedback. At the recording limit, it transcribes the captured audio automatically. It does not use Android's vendor `SpeechRecognizer` or send audio to a recognition service.

On first run, the user explicitly downloads the 77,691,713-byte Whisper tiny model. Talkies verifies the pinned Hugging Face revision, exact byte count, and SHA-256 before installing it. HTTPS access is used solely for this model download; after verification, recording and transcription use the local model and CPU runtime. The user can remove the model from the app. S1-mini cleanup, persistent transcript history, background dictation, and a packaged airplane-mode runtime test are not implemented on Android yet.

Build and run the available tests:

```sh
# From the repository root, fetch the pinned native inference dependency.
git submodule update --init --recursive
cd mobile/android
./gradlew assembleDebug
./gradlew testDebugUnitTest
./gradlew assembleRelease testReleaseUnitTest
```

Requires JDK 17, Android SDK API 36, and NDK 25.2. Android runtime support starts at API 31. Android CI builds and tests both debug and release variants, checks that the APKs contain the native runtime/license but omit model weights, and uploads the tested debug APK as a seven-day artifact. JVM tests verify model download integrity behavior. An API 35 emulator test installs the pinned model before enabling airplane mode, then verifies JNI transcription from the shared JFK fixture while no validated external network is available. The APK includes the whisper.cpp MIT license notice.

## Flutter prototype (legacy)

The old Flutter prototype remains in `mobile/lib/`, `mobile/ios/`, and `mobile/pubspec.yaml` as historical reference. Android no longer uses Flutter. The Flutter app is not actively developed, built, or distributed; its features and setup instructions below are not a statement of current Android functionality.
