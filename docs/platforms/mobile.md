# Mobile

## Android (primary): native Kotlin MVP

Talkies Android is built natively in [`mobile/android/`](../../mobile/android/), using Kotlin, Jetpack Compose, and the Android on-device speech recognition API. The MVP provides microphone permission handling, record/stop controls, an editable transcript, and explicit copy feedback.

The app only creates Android's on-device recognizer when `SpeechRecognizer.isOnDeviceRecognitionAvailable` reports support. It does not declare `INTERNET`, has no cloud fallback, and shows an unavailable message when no on-device recognizer is installed. Recognition and language availability depend on Android/vendor services: the Android MVP does not bundle Whisper weights and must not be described as a bundled or guaranteed offline ASR engine.

Build and run the available tests:

```sh
cd mobile/android
./gradlew assembleDebug
./gradlew testDebugUnitTest
```

Requires JDK 17 and Android SDK API 36. Android runtime support starts at API 31. The automated Android workflow builds the APK, runs unit tests for changes under `mobile/android/`, then uploads the tested debug APK as a seven-day workflow artifact for review and sideload checks.

## Flutter prototype (legacy)

The old Flutter prototype remains in `mobile/lib/`, `mobile/ios/`, and `mobile/pubspec.yaml` as historical reference. Android no longer uses Flutter. The Flutter app is not actively developed, built, or distributed; its features and setup instructions below are not a statement of current Android functionality.
