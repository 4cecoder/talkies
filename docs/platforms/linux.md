# Talkies for Linux

Local-first dictation for X11 and Wayland: hold **Right Alt**, speak, release, and the text is typed
into the focused app. Recording, speech recognition (Phonon-2, with Whisper as the fallback),
optional cleanup and text insertion all run on this computer. For model setup and first-run checks
across platforms, see the
[first-run guide](first-run-and-troubleshooting.md).

## Features

- **Push-to-talk or toggle**: hold Right Alt to dictate, or tap it to start and tap again to stop.
- **Types into the focused app** through `/dev/uinput`, and restores your clipboard afterwards. If
  typing isn't possible, the text is put on the clipboard instead and the panel says so.
- **On-device recognition**: Phonon-2 (English, on CrispASR) once you download it, and Whisper
  (whisper.cpp) for every other case. Optional cleanup by the on-device S1-mini model (downloaded
  from Settings) or by a local Ollama / LM Studio server.
- **Dictation panel and tray** that follow the macOS app: a small waveform pill at the top of the
  screen, a live panel while you dictate, searchable transcript history saved on this computer, and a
  status tray icon.
- **Works across desktops**: GNOME, KDE Plasma, Hyprland, Sway and X11 window managers.
- **`talkies doctor`** checks audio, microphone, hotkey, typing, clipboard, tray and model, and
  tells you how to fix anything that isn't ready.

Ollama and LM Studio cleanup only accept `localhost`, `127.0.0.0/8` or `::1` endpoints. Remote
endpoints are rejected and HTTP redirects are disabled, so transcripts never leave the machine.

Besides the model downloads you ask for, the only network request Talkies makes is the update
check described in [Updates](#updates), which sends no user data and can be turned off.

## Install

Every release on [GitHub Releases](https://github.com/4cecoder/talkies/releases/latest) ships the same
x86_64 build in several formats. It bundles Talkies' Whisper/llama.cpp runtimes, so only standard
desktop libraries (GTK 4, PulseAudio client or pipewire-pulse, SQLite, D-Bus) come from your
distribution. Minimum: glibc 2.35 and GTK 4.6 (Ubuntu 22.04, Debian 12, RHEL 9 or newer) and a CPU
with AVX2 (2013 or newer). CI installs each package on the distributions below before every release.

| Distribution | Package | Install |
| --- | --- | --- |
| Ubuntu 22.04+, Debian 12+, Mint, Pop!_OS | `.deb` | `sudo apt install ./Talkies-Linux-<version>.deb` |
| Fedora, RHEL / Alma / Rocky 9+ | `.rpm` | `sudo dnf install ./Talkies-Linux-<version>.rpm` |
| openSUSE Tumbleweed / Leap | `.rpm` | `sudo zypper install --allow-unsigned-rpm ./Talkies-Linux-<version>.rpm` |
| Arch, Manjaro, EndeavourOS | `.pkg.tar.zst` or AUR `PKGBUILD` | `sudo pacman -U ./Talkies-Linux-<version>.pkg.tar.zst` |
| Gentoo | overlay: `talkies` (source) or `talkies-bin` | see below |
| Anything else (glibc) | `.tar.gz` | `tar xf Talkies-Linux-<version>.tar.gz && sudo ./talkies-*/install.sh` |

Then start **Talkies** from your app menu (or run `talkies daemon`) and run `talkies doctor` if
anything does not work. The first start downloads the Whisper model once (about 150 MB); after that
Talkies runs fully offline. Phonon-2 (674 MB) is downloaded only when you ask for it, under
Settings > Transcription or with `talkies models`.

The packages install a udev rule that gives the logged-in user access to `/dev/uinput`, which Talkies
uses to type text. On Wayland, the Right Alt hotkey additionally needs read access to keyboards:
`sudo usermod -aG input $USER`, then log in again (or bind `talkies-hotkey.sh` in your compositor).

**Arch (AUR-style build).** Download `PKGBUILD` from the release and run `makepkg -si` next to it.

**Gentoo.** Each release ships a ready overlay (`talkies-gentoo-overlay-<version>.tar.gz`, with
Manifests) holding two packages:

- `app-accessibility/talkies` builds from source: the pinned whisper.cpp / llama.cpp and the exact Zig
  compiler the release was tested with (Gentoo does not package Zig master; it is used at build time
  only). `USE=native` builds Talkies and ggml for your CPU instead of the portable baseline.
- `app-accessibility/talkies-bin` installs the prebuilt release under `/opt/talkies`.

```bash
doas mkdir -p /var/db/repos/talkies /etc/portage/repos.conf
doas tar xf talkies-gentoo-overlay-<version>.tar.gz -C /var/db/repos/talkies
printf '[talkies]\nlocation = /var/db/repos/talkies\n' | doas tee /etc/portage/repos.conf/talkies.conf
echo 'app-accessibility/talkies ~amd64' | doas tee /etc/portage/package.accept_keywords/talkies
doas emerge --ask app-accessibility/talkies   # or talkies-bin; USE="X wayland" pull xclip / wl-clipboard
```

**User-only install (no root).** `./talkies-*/install.sh` without sudo installs into `~/.local`;
typing into apps then needs `/dev/uinput` access, which the root install sets up.

**Uninstall.** Use your package manager (`apt remove talkies`, `dnf remove talkies`,
`pacman -R talkies`, `emerge --depclean talkies`) or `./talkies-*/install.sh --uninstall`.
Settings (`~/.config/talkies`), models and transcript history (`~/.local/share/talkies`) are kept.

## Using Talkies

Start **Talkies** from your app menu, or run `talkies daemon` (add it to your session's autostart, or
turn on **Launch at login** in Settings).

### The dictation panel

Talkies rests as a small waveform pill at the top centre of the screen. Click it to open the panel.

| State | What you see |
| --- | --- |
| Ready | Green dot, "Ready to dictate", your hotkey hint, and the last transcript |
| Recording | Red dot, elapsed time, and a live scrolling waveform of your voice |
| Transcribing / cleaning / inserting | Animated waveform and a spinner while the work runs on-device |
| Done | "Text insertion complete" with a **Copy text** button; the panel collapses after 2.5 seconds |
| No speech, manual paste, errors | Stays open with the reason and what to do; move the pointer away to dismiss |

The clock button opens **Transcript History**: your saved transcripts, newest first, 50 at a time
(**Show older** loads more). Type in the search field to filter them (case-insensitive), and use the
buttons on each entry to copy or delete it. **Clear all** (click twice to confirm) deletes every saved
transcript. The search field is the only time the panel takes keyboard focus; on compositors that
never focus it (for example with the Hyprland rules), use `talkies history --search` instead.
**Use mini window** in Settings switches to a compact 360-pixel panel.

### Transcript history

While **Save transcript history** (Settings > General, on by default) is on, every final transcript,
the text that was typed or copied, is saved to
`${XDG_DATA_HOME:-$HOME/.local/share}/talkies/history.sqlite`. The directory is private (`0700`) and
the file is readable only by you (`0600`). Transcripts are kept until you delete them; nothing expires
and nothing leaves the computer. Turning the setting off stops saving but keeps what is already
saved; entries from the current session are still shown until Talkies restarts. Transcript text is
never written to the log.

Each entry also records the recognizer output before cleanup (when cleanup changed it), the audio
length, the speech engine (`phonon` or `whisper`) and the language. The SQLite schema
(`linux/src/app/history_schema.sql`, `PRAGMA user_version = 1`) is shared with the other Talkies
clients; every row has a random UUID so history can later be synced between devices.

```bash
talkies history                         # newest 50
talkies history --search invoice --limit 200
talkies history --json                  # every column, including uuid
talkies history clear                   # delete everything (then VACUUM)
```

### Tray icon

The tray icon shows what Talkies is doing: ready, loading the model, recording, transcribing,
polishing, inserting, finished, or needs attention. Hover it for details. Click it to open or
collapse the panel, middle-click to start or stop recording, and right-click for **Open Talkies**,
**Settings...** and **Quit Talkies**. It works with any StatusNotifierItem host: KDE Plasma, GNOME
with the AppIndicator extension, waybar, AGS and similar bars.

### Settings

Settings has five pages:

- **General**: mini window, launch at login, transcript history, updates, push-to-talk threshold,
  voice assistant mode.
- **Transcription**: microphone, speech engine (Automatic, Phonon-2 or Whisper), the Phonon-2
  download, Whisper model and language, personal vocabulary (one name or uncommon word per line,
  used as Whisper recognition hints).
- **Enhancement**: off, S1-mini (download and manage the model here, then pick writing style,
  structure and context), Ollama or LM Studio.
- **Output**: type at the cursor or copy only, paste shortcut, clipboard restore.
- **Advanced**: config file location and developer options.

A status card at the top of Settings shows the same checks as `talkies doctor`.

### Speech engines

Talkies tries the recognizers in order and uses the first one that works:

1. **Phonon-2**, Fermion Research's compressed NVIDIA Parakeet TDT 0.6B v3 (English only, weights
   CC-BY-4.0), run by [CrispASR](https://github.com/CrispStrobe/CrispASR).
2. **Whisper** (whisper.cpp), the fallback. It is always available.

| `speech_engine` | Uses Phonon-2 when | Otherwise |
| --- | --- | --- |
| `auto` (default) | it is downloaded and the language is English (`en`, `en-US`, ...) | Whisper |
| `phonon` | it is downloaded and the language is English or `auto` | Whisper |
| `whisper` | never | Whisper |

Talkies also falls back to Whisper for a dictation when Phonon-2 fails to load or to transcribe it.
After a load failure, Talkies stops retrying Phonon-2 until you change the speech settings or
restart. Choosing **Phonon-2** in Settings starts its download. **Automatic** never downloads
anything. Phonon-2 ignores the personal vocabulary, and `talkies transcribe --format vtt|srt` always
uses Whisper because it needs Whisper's segment timestamps. `talkies doctor` and the Settings status
card show which engine is in use and why.

### Hotkey on X11 and Wayland

- **X11**: Right Alt works out of the box.
- **Wayland** (GNOME, KDE, Hyprland, Sway): Talkies reads Right Alt directly from the keyboard
  device, which needs read access to keyboards:

  ```bash
  sudo usermod -aG input "$USER"   # then log out and back in
  ```

  If you'd rather not join the `input` group, bind a key in your compositor to the bundled helper,
  `/usr/share/talkies/talkies-hotkey.sh` (`down` / `up` for push-to-talk, `toggle` for tap-to-toggle).
  For Hyprland:

  ```ini
  exec-once = talkies daemon
  bind  = , Alt_R, exec, /usr/share/talkies/talkies-hotkey.sh down
  bindr = ALT, Alt_R, exec, /usr/share/talkies/talkies-hotkey.sh up
  # or a toggle on any chord:
  # bind = SUPER ALT, T, exec, /usr/share/talkies/talkies-hotkey.sh toggle
  ```

  On Hyprland the daemon also sets the window rules for its panel and Settings window at startup.
  `/usr/share/talkies/hyprland-rules.conf` has the same rules if you prefer them in your config.

### Updates

Talkies checks GitHub Releases for a newer Linux build about a minute after the daemon starts and
then once a day, on a background thread. The check is a single HTTPS GET of the release's
`BUILD-INFO.txt` (with curl); nothing about you, your settings or your transcripts is sent, and it
has nothing to do with speech recognition, which stays on this computer.

- Builds from the rolling `latest` prerelease keep the same version number on every push to
  master, so they compare the commit they were built from with the one in `BUILD-INFO.txt`.
- Builds of a tagged release (`vX.Y.Z`, and distro builds such as the Gentoo ebuild) compare
  version numbers with the newest stable release.
- Development and CI builds never check.

When an update exists, Talkies shows a desktop notification once and the **Updates** row in
Settings > General says what to do. Nothing is installed until you click **Install and Restart**
(or confirm `talkies update`). The download goes to `~/.cache/talkies/updates/` and is used only
if its SHA-256 matches the release's `SHA256SUMS`; otherwise it is deleted and the update is
refused. How it is installed depends on how you installed Talkies:

| Installed with | What the update does |
| --- | --- |
| `install.sh` into a prefix you own (e.g. `~/.local`) | Swaps `<prefix>/lib/talkies` for the new version in one rename, refreshes the menu entry and icons, then restarts the daemon |
| `sudo ./install.sh` (e.g. `/usr/local`) | Runs the verified tarball's `install.sh` through `pkexec` |
| `.deb` / `.rpm` / Arch package | Never touches package files itself: after you approve, `pkexec` runs `apt install`, `dnf install` / `zypper install`, or `pacman -U` on the verified package |
| AUR `talkies-bin` | Notification only: update it with your AUR helper |
| Gentoo overlay | Notification only: sync the overlay and `emerge --update` |

For the `pkexec` installs, root copies the download into a private directory and checks its
SHA-256 again before the package manager reads it. After installing, the daemon restarts itself
once no dictation is running: through `systemctl --user restart` when a systemd user unit runs it,
otherwise by starting the new binary in place. `install.sh` records itself in
`<prefix>/lib/talkies/install-method` so the updater can tell its files from a package manager's.

To turn the checks off, switch off **Check for updates automatically** in Settings, set
`check_automatically = false` under `[updates]`, or set `TALKIES_NO_UPDATE_CHECK=1` in the
daemon's environment (this also blocks **Check Now** and `talkies update`).

```bash
talkies update --check    # what is installed, how, and whether a newer build exists
talkies update            # the same, then download, verify and install after you confirm
```

## Configuration

Settings are saved to `~/.config/talkies/config.toml`. Everything is editable in the Settings
window; the file is plain TOML if you prefer editing it directly:

```toml
[general]
push_to_talk_threshold = 0.15   # hold longer than this (s) for push-to-talk; quicker taps toggle
show_hud = true                 # dictation panel
mini_window = false             # compact panel
sounds = false                  # start/stop sounds
voice_assistant_mode = false    # speak the result (spd-say / espeak-ng) instead of typing it

[audio]
device = ""                     # PulseAudio/PipeWire source; empty = default (talkies audio-list)

[transcription]
speech_engine = "auto"          # auto | phonon | whisper (see Speech engines)
model = "base"                  # Whisper model: tiny | base | small | medium | large
language = "en"                 # Phonon-2 needs English; other languages use Whisper
vocabulary_prompt = "Talkies, S1-mini"  # Whisper recognition hints, max 400 characters

[enhancement]
provider = "none"               # none | s1_mini | ollama | lm_studio

[cleanup]                       # S1-mini
style = "semi_formal"           # casual | semi_casual | semi_formal
structure = "prose"             # prose | lists
context = "general"             # general | email

[output]
auto_paste = true               # type at the cursor; false = copy to clipboard only
restore_clipboard = true

[history]
save = true                     # keep transcripts in history.sqlite until you delete them

[updates]
check_automatically = true      # look for a newer build at startup and daily (see Updates)

[vad]
enabled = true                  # trim silence before transcription
```

`[ollama]` and `[lm_studio]` hold the model, endpoint (loopback only) and sampling settings for
those providers.

## Commands

| Command | What it does |
| --- | --- |
| `talkies daemon` | Run Talkies: panel, tray and hotkey |
| `talkies doctor` | Check this system and suggest fixes |
| `talkies models` | Download Phonon-2 (unless `speech_engine = "whisper"`) and the configured Whisper model |
| `talkies audio-list` / `audio-set <device>` | List or choose the microphone |
| `talkies audio` | Record a 5-second test |
| `talkies quick` | Record, transcribe and type once, without the daemon |
| `talkies transcribe <file.wav> --format txt\|vtt\|srt --output <file>` | Export a transcript with timestamps |
| `talkies history [--search Q] [--limit N] [--json]` | List saved transcripts, newest first |
| `talkies history clear` | Delete every saved transcript |
| `talkies update [--check]` | Check GitHub Releases for a newer build; without `--check`, install it after confirmation |
| `talkies config` | Print the current configuration |
| `talkies --version` | Print the version |

Whisper models are pinned to a [specific upstream revision](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1),
checked against their exact size and SHA-256, and verified before each load; verified models work
offline. They live in `~/.local/share/talkies/models/`.

Phonon-2 is pinned the same way, to [`cstr/phonon2-GGUF`](https://huggingface.co/cstr/phonon2-GGUF/tree/3ed3e6ad6e7ce63affffeede37328ff756efaa2f)
at revision `3ed3e6ad`: `phonon2-q8_0.gguf` (674,342,560 bytes) plus its `LICENSE` and `NOTICE`,
each with an exact size and SHA-256. They are stored in
`~/.local/share/talkies/models/phonon2-<revision>/` and verified before each load. Loading never
downloads anything and nothing falls back to a network service.

## Local crash diagnostics

If a command exits with an unhandled error, Talkies best-effort writes a local
report containing the error name, timestamp, and available Zig error-return
stack addresses. Reports are stored under
`${XDG_DATA_HOME:-$HOME/.local/share}/talkies/diagnostics/`, with private
directory and file permissions, a 32 KiB report limit, and five rotating files.
Reports are never uploaded. To remove them, quit Talkies and run:

```sh
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/talkies/diagnostics"
```

## Building from source

Needs Zig master (0.18.0-dev), GTK 4, PulseAudio (or pipewire-pulse), SQLite, X11 and D-Bus
development files, plus the pinned whisper.cpp and llama.cpp that `build-native-deps.sh` builds.
`zig build` fetches the pinned CrispASR v0.8.43 release libraries for x86_64 or aarch64 (hash-pinned
in `build.zig.zon`) and installs them into `zig-out/lib/crispasr/`. Pass `-Dcrispasr=false` to build
without them, for example offline. Talkies then uses Whisper only.

```bash
packaging/linux/build-native-deps.sh            # once; installs into /usr/local
cd linux
zig build -Doptimize=ReleaseSafe                # zig-out/bin/talkies
zig build test                                  # unit tests for every layer
scripts/install.sh --restart                    # developer install, restarts the daemon
```

On Gentoo, `app-accessibility/talkies` from the release overlay does all of this for you.

To build the release packages locally, run
`zig build -Doptimize=ReleaseSafe -Dcpu=x86_64_v2 -Dversion=X.Y.Z` (release CI also passes
`-Dcommit=<sha> -Dchannel=<latest|vX.Y.Z>` for the updater) and then
`VERSION=vX.Y.Z APP_VERSION=X.Y.Z packaging/linux/package.sh`. The output goes to `linux/dist/`, and
`packaging/linux/README.md` describes the pipeline.

The build is split by how often each part changes:

| Binary | Source | Contents |
| --- | --- | --- |
| `talkies` | `src/app`, `src/engine`, `src/core` | Daemon, config, audio, Whisper, hotkey, text insertion |
| `libtalkies-ui.so` | `src/ui` | GTK 4 panel, Settings, tray (StatusNotifierItem over D-Bus) |
| `libtalkies-native.so` | `src/native` | S1-mini cleanup on llama.cpp; the CrispASR loader for Phonon-2 |
| bundled `libwhisper`, `libllama`, `libggml*` | `deps.env` | Pinned runtimes, shared by both models |
| `lib/crispasr/` | `build.zig.zon` | CrispASR with its own ggml, BLAS and OpenMP libraries, plus their notices |

All of these resolve each other through `$ORIGIN`, so the installed tree is relocatable.

CrispASR ships its own ggml under the same sonames as the bundled one, and it exports `whisper_*`
symbols. Talkies therefore never links it. `libtalkies-native.so` loads `lib/crispasr/` with
`dlmopen` into a separate dynamic-linker namespace, so neither library can bind to the other's
symbols. This needs glibc. `TALKIES_CRISPASR_DIR` points Talkies at a different copy of the runtime.
Set `TALKIES_TEST_PHONON=1` to run the Phonon-2 JFK test once the model is installed.

## Troubleshooting

Start with `talkies doctor`; it names the problem and the fix. Common cases:

- **Text isn't typed into apps.** The packages install a udev rule for `/dev/uinput`; log out and in
  once after installing. A manual install needs the rule from `linux/data/70-talkies-uinput.rules`.
  Until then Talkies copies the text to the clipboard and tells you to paste it.
- **Right Alt does nothing on Wayland.** Join the `input` group (see above), or bind the hotkey
  helper in your compositor.
- **No audio or "Microphone unavailable".** Make sure PipeWire (with pipewire-pulse) or PulseAudio
  is running, then pick the microphone with `talkies audio-list` and `talkies audio-set`, or in
  Settings.
- **No tray icon.** Your panel needs a StatusNotifierItem host (on GNOME, the AppIndicator
  extension). The hotkey and panel work without one.
- **"Address already in use" when starting.** Another daemon is running. Quit it from the tray, or
  run `linux/scripts/cleanup.sh` in a source checkout.
- **"Phonon-2 could not load".** `talkies doctor` shows the reason. The CrispASR runtime has to be
  in `lib/crispasr/` next to the `talkies` binary (or in `TALKIES_CRISPASR_DIR`). Until it loads,
  Talkies uses Whisper. To stop trying Phonon-2, set `speech_engine = "whisper"`.
- **GPU.** Whisper (in the packaged build) and Phonon-2 run on the CPU (AVX2). A source build can enable whisper.cpp's
  Vulkan or CUDA backends in `build-native-deps.sh`.

## License

See the repository's LICENSE file. Bundled third-party licenses ship in
`/usr/share/doc/talkies/licenses/`.
