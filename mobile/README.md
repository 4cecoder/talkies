# Talkies Android (Kotlin)

The native Android app in [`android/`](android/) is Talkies' primary Android implementation. It is a small offline-first MVP with an editable transcript, explicit record/stop controls, and copy. It uses Android's **on-device** `SpeechRecognizer` only when the device reports an on-device service; it does not silently fall back to network recognition.

This is not bundled Whisper and does not guarantee offline speech support: availability and language packs depend on the Android device/vendor. Talkies does not request `INTERNET` permission in this app. If no on-device recognizer is available, the UI explains that and does not start recognition. Full local Whisper, cleanup, persistence, background dictation, and feature parity are future work.

## Build and test

Requirements: Android SDK (API 36), JDK 17, and an Android device/emulator running API 31 or later for runtime use.

```sh
cd mobile/android
./gradlew assembleDebug
./gradlew testDebugUnitTest
```

Install the debug APK at `app/build/outputs/apk/debug/app-debug.apk` on a device with an available offline speech recognition service. Grant microphone permission when prompted. The Android workflow builds and runs the unit tests on pull requests that touch `mobile/android/`.

## Legacy Flutter reference

The previous Flutter prototype remains under `lib/`, `ios/`, and the root `pubspec.yaml` for historical reference. Flutter is not used to build the Android app. The iOS Flutter scaffold is not an actively supported release target.
