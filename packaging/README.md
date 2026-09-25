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
| Windows x64 | `Talkies-Windows-{LABEL}-Setup.exe` and `.zip` | Per-user NSIS installer and self-contained published app directory | Run the setup wizard, or expand the ZIP and run `Talkies.Windows.exe`. |
| Linux x86_64 | `Talkies-Linux-{LABEL}.deb` and `.tar.gz` | Debian package or portable `talkies-linux/` directory, with app binary, whisper/llama runtime libraries, and their licenses | Debian/Ubuntu: `sudo apt install ./Talkies-Linux-{LABEL}.deb`. Other distributions: extract the archive and run `talkies-linux/talkies`. |
| All | `SHA256SUMS`, `BUILD-INFO.txt` | Artifact hashes and build provenance | Verify before installation. |

The public macOS DMG and ZIP and the Windows setup EXE are unsigned because CI has no maintainer
signing credentials. Local packaging can sign with an Apple Development identity; that does not make
the public macOS build notarized. The Windows setup installs per-user under
`%LOCALAPPDATA%\Programs\Talkies`; it does not need administrator access. Re-running the installer
updates that install and removes obsolete application files. Uninstalling removes the application
files and shortcuts while preserving settings and model downloads. The ZIP remains available as a
portable fallback. There is no automatic updater or background release check. Open the GitHub
Releases page yourself when you want to check for an update; Talkies does not contact GitHub during
startup, recording, transcription, cleanup, or insertion.

## Verify and install a release

Download all files from the same GitHub Release. In a directory containing the archives and
`SHA256SUMS`, verify the published hashes before expanding them:

```sh
shasum -a 256 -c SHA256SUMS
```

On Linux, `sha256sum -c SHA256SUMS` is also available. On macOS, open the DMG and drag Talkies to
Applications, or expand the ZIP. On Windows, run the setup EXE for the per-user install, or expand
the ZIP for portable use. On Debian/Ubuntu, install the `.deb` with
`sudo apt install ./Talkies-Linux-{LABEL}.deb`; other distributions can use the Linux tarball.
If downloading only one artifact, calculate its SHA-256 with `shasum -a 256 path/to/artifact` on
macOS, `Get-FileHash path/to/artifact -Algorithm SHA256` in PowerShell, or
`sha256sum path/to/artifact` on Linux, then
compare the resulting hash with that artifact's filename entry in the same release's `SHA256SUMS`.
Do not install the artifact if the hash differs or the manifest is unavailable. Public macOS and
Windows builds are currently unsigned and macOS builds are not notarized; hashes detect corruption
but do not replace a code signature or prove publisher identity.
Follow the platform guides for supported OS versions, system dependencies, model downloads, and
offline operation:

- [macOS](../docs/platforms/macos.md)
- [Windows](../docs/platforms/windows.md)
- [Linux](../docs/platforms/linux.md)

First-run model provisioning needs network access. When each required model is downloaded and its
checksum verified, transcription and cleanup use local inference; no hosted inference service is
required.

## Manual updates

Use the newest asset from [GitHub Releases](https://github.com/4cecoder/talkies/releases/latest),
verify it against that release's `SHA256SUMS`, and update using the same install method:

- **macOS:** quit Talkies, open the new DMG, and replace `/Applications/Talkies.app` with the new
  copy. The app bundle can also be replaced from the ZIP.
- **Windows:** close Talkies and run the new setup EXE. It updates the per-user installation and
  replaces obsolete app files. For a portable ZIP, close Talkies and replace the extracted app
  directory with the new archive contents.
- **Debian/Ubuntu:** run `sudo apt install ./Talkies-Linux-{LABEL}.deb`; apt upgrades the installed
  package. For the portable tarball, replace the extracted `talkies-linux/` directory.

## Roll back to a previous release

Download the previous version from [GitHub Releases](https://github.com/4cecoder/talkies/releases),
verify the artifact against that release's `SHA256SUMS`, and install it using the same method as an
update:

- **macOS:** quit Talkies, open the older DMG, and replace `/Applications/Talkies.app` with the
  older copy. You can also restore the app bundle from the older ZIP.
- **Windows:** quit Talkies and run the older per-user setup EXE, or replace the portable app
  directory with the older ZIP contents.
- **Debian/Ubuntu:** install the older package with
  `sudo apt install --allow-downgrades ./Talkies-Linux-{LABEL}.deb`. For a portable installation,
  replace the extracted `talkies-linux/` directory with the older archive contents.

These operations replace application files only. Settings and downloaded models remain in their
user-data directories, so the previous release can be restored without reinstalling models. If an
installation fails, leave the existing user-data directories in place, reinstall the last known-good
release, and use the platform-specific uninstall guide only if you intend to remove local data.

Releases are published on GitHub with generated release notes; the website's downloads page links
to the latest GitHub Release.

## Uninstall and remove local data

The downloads do not install system services. Quit Talkies before removing its app or extracted
folder. Removing the application does not remove model downloads or settings:

- **macOS:** remove `/Applications/Talkies.app`. To also delete S1-mini weights, remove
  `~/Library/Application Support/Talkies/Models/`. WhisperKit's model cache is under
  `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`. Delete either cache only if you
  also want to remove its downloaded models. Talkies preferences are separate in macOS-managed
  preferences.
- **Windows:** use **Uninstall Talkies** in the Start menu for setup installs, or remove the folder
  where you extracted the portable ZIP. Settings and the Whisper cache are under
  `%USERPROFILE%\.talkies\`; the S1-mini weights are under
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

- Documented signing and notarization choices for maintainers, while keeping unsigned builds
  available.
- A tested public release run on clean machines for every OS and architecture.
