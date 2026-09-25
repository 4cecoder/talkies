# Talkies releases and packaging

Talkies publishes desktop downloads through GitHub Releases. Builds, tests, artifact checksums,
and release metadata are handled by
[`.github/workflows/release.yml`](../.github/workflows/release.yml). The app and its inference
runtimes are packaged; speech and cleanup model weights are downloaded and verified on first use,
then kept in user storage for offline inference.

## Release process

`packaging/shared/version.txt` is the app-version source for rolling releases. Push a tag in
`vMAJOR.MINOR.PATCH` form for a versioned release. Push to `master` to publish the serialized
`latest` prerelease. Both paths run platform tests and builds before creating a GitHub Release.
Version tags are validated; the rolling release label is `latest`, while app metadata keeps the
numeric version. The workflow publishes a SHA-256 manifest and `BUILD-INFO.txt` with the artifacts.

| Platform | Release asset | Contents | Current install method |
|---|---|---|---|
| macOS | `Talkies-macOS-{LABEL}.dmg` and `.zip` | DMG contains `Talkies.app`, `llama.framework`, and an `/Applications` shortcut; ZIP contains the app bundle | Open the DMG and drag Talkies to Applications, or expand the ZIP and move `Talkies.app` to `/Applications`. |
| Windows x64 | `Talkies-Windows-{LABEL}.zip` | Self-contained published app directory | Expand to a folder and run `Talkies.Windows.exe`. |
| Linux x86_64 | `Talkies-Linux-{LABEL}.tar.gz` | `talkies-linux/`, app binary, whisper/llama runtime libraries, and their licenses | Extract the archive and run `talkies-linux/talkies`; GTK4, PulseAudio, D-Bus, SQLite, and X11 system libraries are required. |
| All | `SHA256SUMS`, `BUILD-INFO.txt` | Artifact hashes and build provenance | Verify before installation. |

The public macOS DMG and ZIP are unsigned because CI has no maintainer certificate. Local packaging
can sign with an Apple Development identity; that does not make the public build notarized. Windows
archives are unsigned. The release workflow does not currently produce `.pkg`, `.msi`, or `.deb`
installers, and there is no automatic updater.

## Verify and install a release

Download all files from the same GitHub Release. In a directory containing the archives and
`SHA256SUMS`, verify the published hashes before expanding them:

```sh
shasum -a 256 -c SHA256SUMS
```

On Linux, `sha256sum -c SHA256SUMS` is also available. On macOS, open the DMG and drag Talkies to
Applications, or expand the ZIP. For Windows and Linux, expand the platform archive.
Follow the platform guides for supported OS versions, system dependencies, model downloads, and
offline operation:

- [macOS](../docs/platforms/macos.md)
- [Windows](../docs/platforms/windows.md)
- [Linux](../docs/platforms/linux.md)

First-run model provisioning needs network access. When each required model is downloaded and its
checksum verified, transcription and cleanup use local inference; no hosted inference service is
required.

## Uninstall and remove local data

The downloads do not install system services. Quit Talkies before removing its app or extracted
folder. Removing the application does not remove model downloads or settings:

- **macOS:** remove `/Applications/Talkies.app`. To also delete S1-mini weights, remove
  `~/Library/Application Support/Talkies/Models/`. WhisperKit's model cache is under
  `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`. Delete either cache only if you
  also want to remove its downloaded models. Talkies preferences are separate in macOS-managed
  preferences.
- **Windows:** remove the folder where you extracted the zip. Settings and the Whisper cache are
  under `%USERPROFILE%\.talkies\`; the S1-mini weights are under
  `%LOCALAPPDATA%\Talkies\Models\`. Delete those directories only if you want to remove settings
  and downloaded models too.
- **Linux:** remove the extracted `talkies-linux/` directory. Settings are under
  `${XDG_CONFIG_HOME:-$HOME/.config}/talkies/`, and models and local app data are under
  `${XDG_DATA_HOME:-$HOME/.local/share}/talkies/`. Delete those directories only if you want to
  remove settings and downloaded data too.

## Build and verify locally

The release workflow is the authoritative end-to-end packaging path. Local build prerequisites and
platform-specific checks are documented in the platform guides. Useful checks include:

```sh
(cd mac && swift test)
actionlint .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/deploy-pages.yml
```

For a locally signed macOS `.app` zip, provide the certificate identity and actual Team ID:

```sh
SIGNING_IDENTITY="Apple Development: Name (CERTIFICATE_ID)" \
EXPECTED_TEAM_ID="TEAM_ID" \
VERSION="$(tr -d '[:space:]' < packaging/shared/version.txt)" \
OUTPUT_DIR="$PWD/dist" ./packaging/macos/package-app.sh
```

See [macOS packaging](./macos/README.md) and [Windows packaging](./windows/README.md) for
maintainer-only build details. Those guides also describe optional signing; signing credentials
are not required for public open-source builds.

## Release work still outstanding

- Native installable formats and clean-machine install/upgrade/uninstall smoke tests.
- Documented signing and notarization choices for maintainers, while keeping unsigned builds
  available.
- A tested release run on clean machines for every OS and architecture.
- Manual update instructions and a user-facing release-notes path.
