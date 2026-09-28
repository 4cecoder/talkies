# macOS Monterey 12.7.6 compatibility

## Current status

Talkies' current native macOS release does not run on Monterey. Its declared minimum
is macOS 15 in the Swift package and app bundle. This is intentional: the app uses
newer SwiftUI APIs, including `glassEffect`, and its current inference dependencies
cannot be loaded on macOS 12.

The dependency manifests currently pin these minimums:

| Component | Current minimum | Monterey impact |
| --- | --- | --- |
| Talkies app and internal Swift packages | macOS 15 | Package will not build as a Monterey app |
| WhisperKit 1.1.0 | macOS 13 | Not usable on macOS 12 |
| llama.swift 2.10549.0 | macOS 13 | Not usable on macOS 12 |
| Swift 6.3 toolchain | macOS 13 deployment support | Cannot provide a supported macOS 12 target |

References: [Swift platform support](https://www.swift.org/platform-support/),
[WhisperKit](https://github.com/argmaxinc/WhisperKit), and
[llama.swift](https://github.com/mattt/llama.swift).

Changing the package platform declarations or `LSMinimumSystemVersion` to 12 would
be misleading. It would not backport missing system APIs or lower the deployment
minimums of the binary dependencies.

This was checked against the current build: setting
`MACOSX_DEPLOYMENT_TARGET=12.0` did not override SwiftPM's package platform. The
resulting executable still reports `minos 15.0` in its Mach-O build-version load
command. That binary cannot be sent as a Monterey test build.

## Path to real Monterey support

Treat Monterey as a separate compatibility product, rather than weakening the
minimum version of the current release. A Monterey edition needs all of the following:

1. A Swift 5.x compiler and package manifest/tooling that can build for macOS 12.
   The current package manifests require Swift tools 6.3.
2. A local ASR backend with macOS 12 support, likely a Talkies-owned C/C++ adapter
   around whisper.cpp in place of WhisperKit.
3. A local cleanup backend built for macOS 12, in place of the macOS 13-only
   llama.swift XCFramework.
4. Availability-gated UI and system integrations. For example, replace
   `glassEffect` on Monterey and provide a login-item path that does not call
   `SMAppService`, which is unavailable there.
5. A separate package/app identifier or clearly separated release artifact, so
   Monterey users do not receive a bundle that requires a newer OS.
6. A physical macOS 12.7.6 smoke-test machine. Validate first launch, microphone
   permission, local model download, airplane-mode transcription and cleanup,
   text insertion, login behavior, and upgrade/uninstall behavior on that OS.

## Current workaround

There is no supported way to run the current Talkies macOS release on Monterey.
Install and use the current release on macOS 15 or later. Do not edit the app's
minimum-version plist or use compatibility-mode flags: they cannot supply the
missing APIs or inference runtime support.

## Release checklist for a future Monterey build

- Build the dedicated compatibility target with its pinned legacy toolchain.
- Inspect the app bundle and all embedded frameworks for minimum OS metadata.
- Run the Monterey smoke suite on a real 12.7.6 machine with network access disabled
  after model setup.
- Publish it as a distinct artifact with its own minimum OS listed on the download
  page; retain the existing macOS 15+ artifact unchanged.
- Keep all model inference on-device and verify that first-run download is the only
  operation requiring a network connection.
