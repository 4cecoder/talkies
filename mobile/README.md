# Talkies Android (Kotlin)

The native Android app in [`android/`](android/) is Talkies' primary Android implementation. It uses Kotlin/Compose and the pinned whisper.cpp CPU runtime to transcribe audio with a locally downloaded Whisper tiny model. It has an editable transcript, explicit record/stop controls, and copy.

The model is downloaded only after the user chooses **Download Whisper tiny** and is checked against a pinned revision, size, and SHA-256. `INTERNET` permission is used only for that HTTPS download; inference is local. Model-backed device acceptance testing, S1-mini cleanup, persistent history, background dictation, and broader feature parity remain future work.

## Build and test

Requirements: Android SDK (API 36), JDK 17, and an Android device/emulator running API 31 or later for runtime use.

```sh
cd mobile/android
./gradlew assembleDebug
./gradlew testDebugUnitTest
```

Install the debug APK at `app/build/outputs/apk/debug/app-debug.apk`. On first launch, choose **Download Whisper tiny**, then dictate. Grant microphone permission when prompted. Android CI builds, tests, and uploads the APK for changes that touch `mobile/android/`.

## Legacy Flutter reference

The previous Flutter prototype remains under `lib/`, `ios/`, and the root `pubspec.yaml` for historical reference. Flutter is not used to build the Android app. The iOS Flutter scaffold is not an actively supported release target.
