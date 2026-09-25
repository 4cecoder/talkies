# Product vision

## Why

Talkies is an open-source competitor to the growing field of voice-input apps. It should make local dictation feel as quick and polished as the best alternatives, without subscriptions, accounts, or cloud inference.

## Who it is for

People who dictate into many desktop apps, care where their audio goes, or want a capable tool they can inspect, change, and keep using without a paid plan.

## Product rules

1. **Free means free.** Keep the complete supported feature set in the open-source app. Do not add paid gates, account requirements, ads, or usage quotas.
2. **Offline means inference is local.** A first-run model download may need a connection. Once models are present, recording through insertion must work with networking disabled. Never silently fall back to hosted inference.
3. **Make the fast path delightful.** A shortcut, a clear recording state, a short processing step, and text at the cursor should be the primary loop.
4. **Let people choose what persists.** Temporary audio should be deleted after processing. Transcript history should be an explicit local setting with clear retention and deletion controls.
5. **One workflow, native clients.** macOS, Windows, and Linux can use different native APIs, but share product behavior, model metadata, cleanup fixtures, and release expectations.
6. **Keep the voice warm, compact, and a little playful.** Use friendly names and restrained color/character. Avoid turning the dictation surface into a dashboard.

## In scope

- Global hotkey, push-to-talk and toggle dictation, silence handling, microphone selection, and permissions.
- Local model downloads with progress, disk use, integrity checks, selection, and offline availability.
- Local speech recognition followed by optional local cleanup.
- Writing modes, tone, vocabulary, replacements, app-aware defaults, paste/clipboard insertion, and undo/recovery.
- File transcription, local searchable history, export, and meeting capture where platform APIs permit it.
- Native installers and signed/notarized releases when maintainer credentials are available.

## Out of scope

- Hosted transcription, cloud cleanup, remote APIs, and any feature that sends user audio or text to a service.
- Accounts, subscriptions, licensing gates, and telemetry tied to dictation content.
- Mobile in the near-term desktop parity milestone; the existing Flutter app is marked deprecated in the current cleanup PR.

## Privacy acceptance check

With all required models downloaded, block external network access while leaving loopback available, then complete dictation, cleanup, and insertion. Verify that no external request is attempted, local inference may connect only to loopback, temporary audio is removed on success and failure, and transcript storage follows the selected local history setting.
