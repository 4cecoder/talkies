# Mobile

For model setup and offline first-run checks, see the [first-run and troubleshooting guide](first-run-and-troubleshooting.md).
Download the signed Android APK from the [latest Talkies release](https://github.com/4cecoder/talkies/releases/download/latest/Talkies-Android-latest.apk).

## Android (primary): native Kotlin with local Phonon-2 and Whisper

Talkies Android is built natively in [`mobile/android/`](../../mobile/android/), using Kotlin and Jetpack Compose. Stable transcript and cleanup contracts, the `LocalSpeechRuntime` recognizer interface, and the speech-engine selection and fallback policy (`SpeechEngineSelection`, `SpeechRecognizerChain`) live in the JVM-only `:core` module. The separate Android `:inference` library owns verified model stores, JNI, CrispASR, whisper.cpp, llama.cpp, and local inference. The `:app` module owns Compose UI, the speech-engine setting, microphone capture, and input-method lifecycle. It records 16 kHz mono audio in memory for at most five minutes per dictation, runs a downloaded speech model through JNI, and presents an editable transcript with explicit copy feedback. At the recording limit, it transcribes the captured audio automatically. It does not use Android's vendor `SpeechRecognizer` or send audio to a recognition service.

### Speech engines

Talkies runs one of two local recognizers, chosen by the **Speech engine** setting:

| Setting | Order tried |
|---|---|
| Automatic (default) | Phonon-2, then Whisper tiny |
| Phonon-2 | Phonon-2, then Whisper tiny |
| Whisper | Whisper tiny only |

A runtime is skipped when its model is missing or fails verification, or when its native library cannot load. If Phonon-2 throws while loading or transcribing, the same in-memory audio is passed to Whisper tiny and the status line names the fallback. A model that fails to load is not retried until its file changes or is deleted. A blank transcript counts as silence and does not trigger a fallback. Choosing Whisper never runs Phonon-2.

- **Phonon-2** (default when installed): Fermion Research's compressed NVIDIA Parakeet TDT 0.6B v3, English only. Android downloads `phonon2-q4_k.gguf` (402,226,656 bytes; 402.2 MB) plus its `LICENSE` and `NOTICE` from [`cstr/phonon2-GGUF`](https://huggingface.co/cstr/phonon2-GGUF) at revision `3ed3e6ad6e7ce63affffeede37328ff756efaa2f`, 402.2 MB in total. The weights are CC-BY-4.0. The download button and screen show the size, and the download is refused when app storage has less free space than that. All three files are pinned by exact size and SHA-256 and are stored in `files/models/Phonon-2-<revision>/`. Phonon-2 runs through [CrispASR](https://github.com/CrispStrobe/CrispASR)'s Parakeet TDT backend on the CPU. It transcribes in bounded windows of about 30 seconds with CrispASR's gap-fill repair, which keeps encoder memory flat for a five-minute dictation. The loaded model stays resident between dictations and is unloaded before deletion.
- **Whisper tiny** (77.7 MB, multilingual): the small fallback and the explicit choice for low-storage devices, run through whisper.cpp.

### Cleanup, keyboard, and supported devices

Talkies also includes an Android remote companion for Linux development sessions. Add a host name,
address, SSH port, and username. SSH passwords are requested on first connection, then can be
remembered with an explicit opt-in. Saved passwords are encrypted with an Android Keystore key,
bound to the host profile, and stored outside device backup; reconnects use them without another
prompt. Removing a host also removes its saved password. New SSH host keys are shown for explicit
trust-on-first-use approval and stored in the app-private `known_hosts` file; changed keys fail
closed. The embedded ConnectBot/libvterm terminal
supports interactive shells, terminal resizing and colors, and reconnecting to long-lived sessions
such as Herdr with `herdr session list` or `herdr session attach`. The local **Dictate** control
transcribes on-device and types into the shell without Enter, so the user reviews before running it.
The companion scans the remote host for Herdr agents and cmux terminal surfaces, shows their state
across selectable running Herdr sessions and cmux workspaces, and displays recent output. You can
dictate into a separate prompt composer. Talkies refreshes the
target before sending; Herdr prompts are refused unless the agent is idle, and cmux delivery checks
that the target is still an agent with no open draft or dialog. Sending is always an explicit user
action after reviewing the prompt. cmux discovery requires its CLI and socket permissions on the
remote Mac; its optional socket password is held in memory and forwarded through an SSH environment
request, so the remote sshd must allow `CMUX_SOCKET_PASSWORD` with `AcceptEnv`. Herdr state is read
through its machine-readable CLI.
This initial remote transport supports SSH; Mosh transport and Android background-session survival
remain follow-up work. SSH transport and terminal UI run behind an app-layer boundary so either can
be changed without touching speech recognition or transcript policy.

When Talkies is selected as the Android keyboard inside a recognized terminal app, it uses a
terminal-aware dictation path: it skips optional LLM cleanup to keep agent prompts and code symbols
unaltered, does not add terminal text to transcript history, and inserts the transcript without
pressing Enter. The keyboard status makes the destination clear and reminds the user to review the
text before sending it. Moshi, Termux, ConnectBot, JuiceSSH, and common SSH/terminal package names
are recognized. This works with the local speech models and does not send audio or transcript text
to a service. Additional companion features remain tracked in Kanban; the app can also dictate into SSH
terminal apps through the Android input method. See the [agent-aware dictation architecture](../architecture/agent-aware-dictation.md)
for the desktop and mobile roadmap.

The user explicitly downloads at least one speech model before dictating. Optional cleanup is a separate, opt-in S1-mini download (484,219,808 bytes, about 462 MiB). All models are revision-pinned and SHA-256 verified; the S1-mini Apache 2.0 `LICENSE` and `NOTICE` and the Phonon-2 CC-BY-4.0 `LICENSE` and `NOTICE` are stored alongside their weights. HTTPS is used only for a model download the user starts. Phonon-2, Whisper, and S1-mini then run on the device with CPU inference and no service fallback. Cleanup offers casual, semi-casual, balanced, semi-formal, and formal tone choices, plus prose or list formatting and general or email context. Balanced maps to the model's trained semi-formal prompt value. S1-mini stays loaded in the app process after its first use and is unloaded before deletion. The user can remove each model separately.

Talkies also provides a native Kotlin input method for direct dictation into the focused field in other apps. It uses the same speech-engine setting and fallback chain. First download a speech model and grant microphone permission in Talkies, then use **Enable keyboard** in the app screen and enable Talkies voice typing in Android system settings. Use the system keyboard picker to select it. The keyboard records only while its Record control is active, applies the same optional local S1-mini settings, and commits the result into the current text field. When **Save transcript history** is on, it saves the inserted text to the same local history, except in password fields and fields that request no personalized learning (incognito). Some secure or app-restricted fields may not allow third-party keyboard input. Leaving the keyboard while recognition is in progress prevents a delayed insertion into a later field.

### Transcript history

Talkies saves each finished dictation, from the app screen and the keyboard, in a local SQLite database at `databases/history.sqlite` in the app's private storage. It uses the framework `SQLiteOpenHelper` in WAL mode with `secure_delete` on. The database uses the shared cross-platform `transcripts` schema (`TranscriptHistorySchema` in `:core`, version 1): a random lowercase UUIDv4 per row, the creation time in UTC epoch milliseconds, the final inserted text, the recognizer output before cleanup (NULL when cleanup left it unchanged), the audio length, the runtime (`phonon` or `whisper`), and the language (`en` for Phonon-2, NULL for Whisper because its detected language is not reported). The **Save transcript history** setting is on by default. Turning it off stops saving and keeps existing entries. Entries do not expire.

**View history** opens the History screen. It lists saved dictations newest first, 50 at a time, and supports a search that matches text literally through a parameterized `LIKE`. You can copy or delete an entry. **Clear all**, on the History screen or beside the setting, asks for confirmation, then deletes every row, runs `VACUUM`, and truncates the WAL. Database work runs off the main thread, and transcript text is never logged. Android's backup and data-extraction rules exclude the database from cloud backup and device-to-device transfer. The `TranscriptHistoryStore` interface in `:core` keeps the local store self-contained; history is not synced or paired with another device.

Background dictation is not implemented on Android. Android supports API 28 and newer, including Fire OS 7 tablets (Android 9/API 28) and Fire OS 8 (Android 11/API 30). The app keeps target API 35 for current Android behavior; its minimum API supports Fire OS 7 and newer. Android CI pre-provisions both models, disables Wi-Fi and mobile data, enables airplane mode, then verifies actual Whisper recognition and S1-mini cleanup on an API 28 emulator, the lowest supported Fire tablet API baseline. See [Amazon's Fire OS 7](https://developer.amazon.com/docs/fire-tablets/fire-os-7.html) and [Fire OS 8](https://developer.amazon.com/docs/fire-tablets/fire-os-8.html) guidance for OS-to-API mapping.

### Native runtime build

`libtalkies_whisper.so` links whisper.cpp and llama.cpp. Phonon-2 is a separate `libtalkies_phonon.so`, so a device that cannot load it still dictates with Whisper tiny. CrispASR is a pinned submodule at `mobile/android/third_party/CrispASR` (tag `v0.8.43`, commit `eb633d908120cc5f44b8af8cd4aeb1191f16bfd8`). It carries its own nested `ggml` fork and a `c2pa-audio` submodule; CrispASR's configure step checks for the latter. CrispASR's ggml fork and its `whisper` CMake target collide with the whisper.cpp and llama.cpp targets, and CrispASR resolves paths from `CMAKE_SOURCE_DIR`. For those reasons [`inference/src/main/cpp/CMakeLists.txt`](../../mobile/android/inference/src/main/cpp/CMakeLists.txt) configures it as a separate CMake project through `ExternalProject`, with the same NDK toolchain, ABI, and platform. Only the `parakeet` target and its `crispasr-core` and `ggml` dependencies are compiled. The other CrispASR backends, its C ABI library, and every configure-time download (Opus, AMR, C2PA, KleidiAI, OpenMP) are disabled. The JNI adapter (`phonon_jni.cpp`) links those static archives and uses a version script to export only its three `Java_com_talkies_android_LocalPhonon_*` entry points. Neither runtime's `ggml_*` or `whisper_*` symbols are visible to the other. The adapter copies PCM into memory it owns and wipes that copy and the transcript buffers after each call. The stripped library is about 1.7 MB for arm64-v8a and 2.0 MB for x86_64, much smaller than CrispASR's 217 MB all-backend release library. The CrispASR and CrispASR ggml MIT licenses ship in `assets/licenses/`.

Build and run the available tests:

```sh
# From the repository root, fetch the pinned native inference dependency.
git submodule update --init --recursive
cd mobile/android
./gradlew assembleDebug :core:test :inference:testDebugUnitTest :app:testDebugUnitTest
./gradlew assembleRelease :inference:testReleaseUnitTest :app:testReleaseUnitTest
```

Requires JDK 17, Android SDK API 36, CMake 3.31.6, and NDK 27.2. Android runtime support starts at API 28. Android CI builds and tests both debug and release variants, checks that the APKs contain the native runtimes and their license notices but omit model weights, and uploads the tested debug APK as a seven-day artifact. Core JVM tests cover transcript spacing, bounded PCM behavior, the shared cleanup prompt/output contract, and speech-engine selection and fallback. Inference module tests cover pinned model integrity and verified installation for Whisper tiny and Phonon-2, including its attribution files. App tests cover speech-engine status and download-size text, history text, and the keyboard's password and incognito exclusion. The emulator's `AndroidSshCredentialStoreTest` verifies Android Keystore encryption, profile binding, and credential deletion. Core tests cover the history schema, row rules, UUIDs, search escaping, and keyset paging. `SqliteTranscriptHistoryStoreTest` runs the SQLite store on the emulator in a throwaway database: WAL mode, schema, paging, literal search, delete, and clear. `LocalPhononOfflineAcceptanceTest` runs real Phonon-2 recognition with networking disabled when `files/models/Phonon-2-<revision>/` and `files/fixtures/jfk.wav` are pre-provisioned, and is skipped otherwise. API 28 emulator acceptance verifies real Whisper transcription and S1-mini transcript cleanup with external networking disabled. The app includes the whisper.cpp, llama.cpp, CrispASR, and CrispASR ggml MIT license notices. It retains S1-mini's upstream Apache 2.0 files and Phonon-2's CC-BY-4.0 files beside their separately downloaded weights.

## Deprecated Flutter prototype

The former Flutter/Dart prototype is preserved in [`archive/flutter-prototype/`](../../archive/flutter-prototype/README.md)
for historical reference. It is not built, tested, or distributed, and it is not an iOS release
target. Do not use its setup notes to build the supported Android app; use the native Kotlin project
in [`mobile/android/`](../../mobile/android/) instead.
