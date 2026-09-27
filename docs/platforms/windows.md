# Talkies for Windows

Talkies is a free, MIT-licensed Windows dictation app. It records audio locally, transcribes with Whisper, and can optionally polish the transcript with S1-mini running on the CPU. Transcripts can be inserted into the focused app or exported. Model downloads need a network connection; recording, transcription, cleanup, and insertion run offline after the selected models are installed.

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
- **Update:** Quit Talkies and run the newer setup executable. App files are replaced; settings and downloaded models are kept.
- **Uninstall:** Select **Uninstall Talkies** from the Start menu. This removes the installed app and shortcuts but keeps settings and model files.

Talkies stores settings at `%USERPROFILE%\.talkies\config.json` and Whisper models in `%USERPROFILE%\.talkies\models`. S1-mini weights and their upstream `LICENSE` and `NOTICE` are stored under `%LOCALAPPDATA%\Talkies\Models`. To remove personal data as well, quit Talkies and delete those folders.

The first use of a Whisper model downloads and verifies that model. S1-mini downloads its approximately 462 MiB English cleanup model the first time cleanup is used. S1-mini is a post-processor; Whisper performs speech recognition. The app includes the S1-mini model's required attribution files after download.

## Use Talkies

1. Select a microphone and a Whisper model in the app.
2. Press the **Right Alt** key or use the recording control to start and stop recording.
3. Review the transcript. Enable S1-mini cleanup in the app if you want it to remove disfluencies and format the recognized text.
4. Insert the transcript into the focused app or export it as SRT, TXT, or VTT.

Larger Whisper models can improve recognition quality but need more memory and take longer to run. S1-mini cleanup currently supports English.

## Privacy and network use

Audio and transcript text are processed on the device. The app does not send them to a cloud inference service. Network access is used to download missing models over HTTPS. Optional Ollama and LM Studio providers are supported only at loopback addresses, with HTTP redirects disabled.

## Troubleshooting

### A model is missing or won't download

Check that the device has an internet connection for the first download and enough free disk space. Talkies verifies downloaded model size and SHA-256 before installing it; an interrupted or invalid download is not accepted. Retry the download from the app. After download, the model can be used offline.

### Local provider is unavailable

For Ollama or LM Studio, start the local server and confirm its endpoint uses `localhost` or a loopback IP address. Remote inference endpoints are rejected.

### Transcription quality is poor

Try a larger Whisper model, select the spoken language when known, and check microphone input and recording levels.

For more help, see the [Windows quick reference](../../windows/QUICK_REFERENCE.md) and [Windows developer guide](../../windows/DEVELOPER_GUIDE.md).

## Build and test from source

Development requires the .NET 8 SDK and Windows for running the WPF application. From the repository root:

```powershell
cd windows/Talkies.Windows
uv run dotnet build
uv run dotnet test ../Talkies.Windows.Tests
```

Windows CI builds and tests the application, exercises cached local-model inference with network access denied, and smoke-tests the release packages. The local-model integration test requires pre-provisioned model files; see the [CI workflow](../../.github/workflows/ci.yml) for its model setup and test configuration.

## License

Talkies is licensed under the [MIT License](../../LICENSE). S1-mini model weights are separately licensed; see the model's included `LICENSE` and `NOTICE` files and the [upstream model repository](https://huggingface.co/superwhisper/s1-mini-GGUF).
