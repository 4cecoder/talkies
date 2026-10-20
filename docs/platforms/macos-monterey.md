# macOS Monterey 12.7.6 compatibility

## Current status

The normal Talkies macOS release does not run on Monterey. Its declared minimum is
macOS 15 in the Swift package and app bundle. It uses newer SwiftUI and system APIs,
and its current inference dependencies cannot be loaded on macOS 12.

The `mac/Monterey` directory now contains a separate compatibility preview. It is
built against macOS 12 using whisper.cpp and llama.cpp executables from the pinned
submodules. Apple silicon uses Metal with CPU fallback; Intel uses CPU-only
inference and a smaller Whisper model. It supports microphone recording, Whisper
transcription, optional S1-mini cleanup, and explicit copy. It does not yet provide
the full release app's activation shortcut, direct text insertion, menu-bar controls,
settings, or export workflow. **It is not yet verified on a real Monterey 12.7.6 Mac.**

The dependency manifests currently pin these minimums:

| Component | Current minimum | Monterey impact |
| --- | --- | --- |
| Released Talkies app and internal Swift packages | macOS 15 | Package will not build as a Monterey app |
| WhisperKit 1.1.0 | macOS 13 | Not usable on macOS 12 |
| llama.swift 2.10549.0 | macOS 13 | Not usable on macOS 12 |
| Swift 6.3 toolchain | Officially supported down to macOS 13 | The Monterey preview emits a macOS 12 target; runtime behavior still requires physical-machine validation |

References: [Swift platform support](https://www.swift.org/platform-support/),
[WhisperKit](https://github.com/argmaxinc/WhisperKit), and
[llama.swift](https://github.com/mattt/llama.swift).

Changing the release package platform declarations or `LSMinimumSystemVersion` to
12 alone would be misleading. It would not backport missing system APIs or lower
the deployment minimums of the binary dependencies.

This was checked against the current app build: setting
`MACOSX_DEPLOYMENT_TARGET=12.0` did not override SwiftPM's package platform. The
resulting executable still reports `minos 15.0` in its Mach-O build-version load
command. A separate dependency-free SwiftPM probe with an explicit `.macOS(.v12)`
target did emit a binary marked `minos 12.0`; this proves the compiler can produce
such a binary, but does not prove Swift's runtime or the current app dependencies
work on Monterey. That app binary cannot be sent as a Monterey test build.

## Path to real Monterey support

Treat Monterey as a separate compatibility product, rather than weakening the
minimum version of the current release. A Monterey edition needs all of the following:

1. Keep the dedicated Swift package at macOS 12 and pin the Swift toolchain used to
   build the preview. The current release package remains on tools 6.3/platform 15.
2. Keep whisper.cpp and llama.cpp executables built with `minos 12.0`; use Metal on
   Apple silicon and CPU inference on Intel. Avoid the optional BLAS path because
   its current implementation references an Accelerate symbol introduced in macOS
   13.3.
3. Add the remaining activation, safe cursor insertion, settings, and export features
   using APIs available on Monterey.
4. Publish a distinct architecture-aware ZIP with its own minimum OS and clear
   preview label, so users don't confuse it with the macOS 15+ release.
5. Run a physical macOS 12.7.6 smoke test. Validate first launch, microphone
   permission, local model download, airplane-mode transcription and cleanup,
   clipboard safety, and upgrade/uninstall behavior on that OS.

The current universal preview ZIP is a test artifact, not a claim of completed
Monterey validation. Its bundled binaries target macOS 12.0, but first launch,
permissions, transcription, and cleanup still need confirmation on a real 12.7.6
machine.

## Current workaround

The current Talkies macOS release still requires macOS 15 or later. Use the separate
Monterey preview from `mac/Monterey` only for compatibility feedback; it is not a
replacement for the full native app until its missing features are ported and it has
passed testing on a real Monterey Mac. Do not edit the main app's minimum-version
plist or use compatibility-mode flags: that cannot supply the missing APIs or
inference runtime support.

## Preview validation still needed

- Test first launch and microphone permission on macOS 12.7.6.
- Verify model downloads, transcription, and optional cleanup, then repeat offline.
- Check clipboard writes, app quit/reopen, and model persistence after an app update.
- Report the tester Mac's architecture, macOS version, errors, and inference times.
- Only call Monterey supported after these checks pass on real hardware.
