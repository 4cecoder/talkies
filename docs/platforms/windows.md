# Talkies for Windows

Talkies is a free, MIT-licensed Windows dictation app. It records audio locally, transcribes English with Phonon-2 (when downloaded) and every other language with Whisper, and can optionally polish the transcript with S1-mini running on the CPU. Transcripts can be inserted into the focused app or exported. Model downloads need a network connection; recording, transcription, cleanup, and insertion run offline after the selected models are installed.

## Install, update, and uninstall

Download the current packages from [Talkies releases](https://github.com/4cecoder/talkies/releases). The rolling `latest` release is a prerelease, and public Windows packages are currently unsigned. Check the release notes before installing.

To verify the setup executable, download `SHA256SUMS` from the same release and compare the Windows setup entry:

```powershell
$expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match '  Talkies-Windows-latest-Setup\.exe$' }) -split '\s+')[0]
$actual = (Get-FileHash .\Talkies-Windows-latest-Setup.exe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'Talkies setup checksum does not match SHA256SUMS.' }
```

- **Setup installer:** Run `Talkies-Windows-latest-Setup.exe`. It installs per-user under `%LOCALAPPDATA%\Programs\Talkies` and adds a Start menu shortcut. The package is self-contained and does not require a separately installed .NET runtime.
- **Portable ZIP:** Extract `Talkies-Windows-latest.zip` and run `Talkies.Windows.exe`. Delete the extracted folder to remove the portable app.
- **Optional GPU runtimes:** The standard app includes Whisper CPU runtimes and the CPU-only CrispASR runtime used by Phonon-2. If you have a compatible accelerator, download only the matching `Talkies-Windows-Whisper-CUDA13-Runtime-latest.zip`, `Talkies-Windows-Whisper-CUDA12-Runtime-latest.zip`, or `Talkies-Windows-Whisper-Vulkan-Runtime-latest.zip`. Verify it with `SHA256SUMS` and extract it into the installed or portable Talkies app directory so its `runtimes` folder merges. Restart Talkies. CUDA requires compatible NVIDIA drivers/toolkit; Vulkan requires a compatible Vulkan driver/runtime. Without a usable GPU runtime, Whisper continues on CPU. S1-mini cleanup remains CPU-only. Reinstall the add-on after updating Talkies with the setup installer.
- **Update:** Quit Talkies and run the newer setup executable. App files are replaced; settings and downloaded models are kept.
- **Uninstall:** Select **Uninstall Talkies** from the Start menu. This removes the installed app and shortcuts but keeps settings and model files.

Talkies stores settings at `%USERPROFILE%\.talkies\config.json`, Whisper models in `%USERPROFILE%\.talkies\models`, and transcript history in `%LOCALAPPDATA%\Talkies\history.sqlite`. S1-mini and Phonon-2 weights, each with its upstream `LICENSE` and `NOTICE`, are stored under `%LOCALAPPDATA%\Talkies\Models`. To remove personal data as well, quit Talkies and delete those folders.

To verify an optional runtime archive, set `$asset` to its exact filename and compare it with the same release's manifest:

```powershell
$asset = 'Talkies-Windows-Whisper-Vulkan-Runtime-latest.zip'
$line = Get-Content .\SHA256SUMS | Where-Object { $_ -match ("  " + [regex]::Escape($asset) + '$') } | Select-Object -First 1
if (-not $line) { throw "No checksum entry found for $asset." }
$expected = ($line -split '\s+')[0]
$actual = (Get-FileHash ".\$asset" -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw "Checksum mismatch for $asset." }
```

The first use of a Whisper model downloads and verifies that model. Phonon-2 (about 643 MiB) is downloaded only when you select **Download Phonon-2** in the transcription settings; until then Talkies uses Whisper. S1-mini downloads its approximately 462 MiB English cleanup model the first time cleanup is used. S1-mini is a post-processor; Whisper performs speech recognition. The app includes the S1-mini model's required attribution files after download.

## Use Talkies

1. Select a microphone, a speech engine, and a Whisper model in the app.
2. Press the **Right Alt** key or use the recording control to start and stop recording.
3. Review the transcript. Enable S1-mini cleanup in the app if you want it to remove disfluencies and format the recognized text.
4. Insert the transcript into the focused app or export it as SRT, TXT, or VTT.

Larger Whisper models can improve recognition quality but need more memory and take longer to run. S1-mini cleanup currently supports English.

### Speech engines

**Speech engine** in the transcription settings chooses how recordings are recognized:

| Setting | English or `auto` language | Any other language |
|---|---|---|
| **Automatic (Phonon-2 for English, Whisper otherwise)** (default) | Phonon-2 if downloaded, otherwise Whisper | Whisper |
| **Phonon-2** | Phonon-2, with Whisper as fallback | Whisper (Phonon-2 is English-only) |
| **Whisper** | Whisper | Whisper |

Phonon-2 is Fermion Research's compressed NVIDIA Parakeet TDT 0.6B v3 model. It is English-only and runs on the CPU through the bundled [CrispASR](https://github.com/CrispStrobe/CrispASR) 0.8.43 runtime. With the language set to `auto`, Automatic treats speech as English once Phonon-2 is downloaded; select your language if you dictate in another language. If Phonon-2 is not downloaded, fails its SHA-256 check, fails to load, or fails to transcribe, Talkies transcribes the same recording with Whisper and shows why under the engine selector. Whisper is never removed or disabled by this setting, and there is no network fallback.

Phonon-2 runs in a separate `Talkies.Windows.exe --crispasr-worker` process that keeps the model loaded between dictations. Expect it to use up to about 1 GB of additional memory while Phonon-2 is active. The first dictation after start-up also verifies the model's SHA-256 and loads it, which takes a few seconds.

### Transcript history

With **Save transcript history** on (the default, under **Transcript History** in the sidebar), each finished dictation is saved after cleanup to `%LOCALAPPDATA%\Talkies\history.sqlite`, together with the recognizer output before cleanup (when it differs), the recording length, the speech runtime that produced it (Phonon-2 or Whisper), and the language when known. Nothing expires automatically. Turning the setting off stops saving new dictations; it does not delete existing history.

Open **History** from the tray icon menu or **Open History** in the sidebar to browse saved transcripts newest first, search them, copy one to the clipboard, or delete one. **Clear All** (in the History window) and **Clear History** (in the sidebar) ask for confirmation, then delete every transcript and compact the database file. Transcript text is never written to the log.

The database is SQLite in WAL mode and uses the schema shared by all Talkies clients, versioned with `PRAGMA user_version` (currently 1):

```sql
CREATE TABLE IF NOT EXISTS transcripts (
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,     -- random lowercase UUIDv4, stable across devices
  created_at INTEGER NOT NULL,   -- Unix epoch milliseconds, UTC
  text TEXT NOT NULL,            -- final text that was inserted (after cleanup)
  raw_text TEXT,                 -- recognizer output before cleanup; NULL when identical
  duration_ms INTEGER,           -- audio length
  runtime TEXT,                  -- 'phonon' | 'whisper'
  language TEXT                  -- NULL when unknown
);
CREATE INDEX IF NOT EXISTS transcripts_created_at ON transcripts(created_at DESC);
```

A history file created by a newer Talkies version is left untouched, and the app reports that history is unavailable instead of downgrading it. To remove history manually, quit Talkies and delete `history.sqlite` and any `history.sqlite-wal` and `history.sqlite-shm` files beside it.

## Privacy and network use

Audio and transcript text are processed on the device. The app does not send them to a cloud inference service, and transcript history stays in a local file. Network access is used to download missing models over HTTPS. Optional Ollama and LM Studio providers are supported only at loopback addresses, with HTTP redirects disabled.

## Troubleshooting

See the shared [first-run and troubleshooting guide](first-run-and-troubleshooting.md) for model setup, offline checks, and cache recovery.

### A model is missing or won't download

Check that the device has an internet connection for the first download and enough free disk space. Talkies verifies downloaded model size and SHA-256 before installing it; an interrupted or invalid download is not accepted. Retry the download from the app. After download, the model can be used offline.

### Local provider is unavailable

For Ollama or LM Studio, start the local server and confirm its endpoint uses `localhost` or a loopback IP address. Remote inference endpoints are rejected.

### Transcription quality is poor

Try a larger Whisper model, select the spoken language when known, and check microphone input and recording levels. For non-English speech, set the language explicitly so Automatic uses Whisper instead of the English-only Phonon-2.

### Phonon-2 is not used

The text under **Speech engine** gives the reason. Common causes are a non-English language, Phonon-2 not yet downloaded, or a failed load. After two worker failures in one session, Talkies stops trying Phonon-2 until you restart the app. To reinstall Phonon-2, quit Talkies, delete `%LOCALAPPDATA%\Talkies\Models\Phonon-2-*`, restart, and download it again.

For more help, see the [Windows quick reference](../../windows/QUICK_REFERENCE.md) and [Windows developer guide](../../windows/DEVELOPER_GUIDE.md).

## Build and test from source

Development requires the .NET 8 SDK and Windows for running the WPF application. From the repository root:

```powershell
cd windows/Talkies.Windows
uv run dotnet build
uv run dotnet test ../Talkies.Windows.Tests
```

The build downloads the pinned CrispASR 0.8.43 CPU archive (`libcrispasr-windows-x86_64.tar.gz`) from its GitHub release once, to `windows/Talkies.Windows/obj/crispasr/`. It verifies the archive and every shipped DLL and notice against SHA-256 values pinned in `Talkies.Windows.csproj`, then copies them to `crispasr\` and `licenses\CrispASR\` in the build and publish output. CrispASR's DLLs stay in their own folder and only load in the worker process, because their `ggml*.dll` names match the DLLs LLamaSharp loads for S1-mini. For offline builds, pass `-p:CrispAsrArchivePath=<path to the verified archive>`; `-p:TalkiesIncludeCrispAsrRuntime=false` builds without Phonon-2, and Talkies then uses Whisper.

Windows CI builds and tests the application, exercises cached local-model inference with network access denied, and smoke-tests the release packages. The local-model integration test requires pre-provisioned model files; see the [CI workflow](../../.github/workflows/ci.yml) for its model setup and test configuration.

## License

Talkies is licensed under the [MIT License](../../LICENSE). S1-mini model weights are separately licensed; see the model's included `LICENSE` and `NOTICE` files and the [upstream model repository](https://huggingface.co/superwhisper/s1-mini-GGUF). Phonon-2 weights are licensed under CC-BY-4.0 (derived from NVIDIA Parakeet TDT 0.6B v3); their `LICENSE` and `NOTICE` are downloaded with them from the [pinned model revision](https://huggingface.co/cstr/phonon2-GGUF/tree/3ed3e6ad6e7ce63affffeede37328ff756efaa2f). The bundled CrispASR runtime is MIT-licensed; its license and third-party notices ship in `licenses\CrispASR\`. Transcript history uses Microsoft.Data.Sqlite (MIT) with SQLitePCLRaw (Apache-2.0) and its bundled public-domain SQLite build; see `THIRD-PARTY-NOTICES.txt`.
