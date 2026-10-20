# Agent-aware dictation

Talkies keeps ordinary dictation simple: capture speech locally, recognize it on-device, and insert
text into the focused field. Agent-aware dictation adds a deliberate destination for coding-agent
workflows on desktop and Android. It must remain fast, predictable, and private without changing
normal voice typing.

## Product behavior

- Detect or let the user select the current agent destination. Show its name before delivery.
- Preserve the user's words and code identifiers. Optional LLM cleanup is skipped in agent mode.
- Stage dictated text for review. In a terminal, insert text only; never synthesize Enter or run a
  command automatically.
- Keep speech recognition on-device. Do not send recordings or transcripts through a Talkies cloud
  service. Keep agent prompts out of history by default.
- Report capture-to-preview and preview-to-delivery timing so latency work is measurable.
- Make normal dictation the default and provide an obvious way back to it.

## Platform adapters

| Platform | Current foundation | Agent-aware direction |
| --- | --- | --- |
| macOS | cmux connector and guarded agent mode on `master` | Resolve the selected cmux agent, preview, and deliver only when the connector confirms the target is safe. |
| Linux | GTK/Zig recorder, local speech pipeline, terminal-friendly paste | Add explicit Herdr/terminal target awareness and staged delivery without guessing which shell command to run. |
| Android | Native offline speech models, terminal-app-aware input method, and an SSH companion with host profiles, TOFU host-key checks, an interactive terminal, Herdr shortcuts, and local dictation | Add Mosh transport and a lifecycle-safe background session service; preserve explicit review before terminal submission. |
| Windows | Native offline dictation and text insertion | Keep ordinary insertion stable; assess agent destinations through a Windows-specific adapter. |

Platform-specific discovery and delivery stay outside stable speech contracts. The Android `:core`
module owns the destination policy and unit-tested decisions; `:app` owns `EditorInfo`, the input
method lifecycle, and UI status. SSH, terminal rendering, and multiplexer protocol code belong in
separate Android adapters. The SSH transport, profile store, terminal emulator, and speech path are
separate from one another so each can evolve without changing the shared speech contracts.

## Latency and safety checks

Measure the time from stopping capture to seeing the editable transcript, plus the time from review
to delivery. Keep the recognizer warm when the platform permits it, do file and model work off the UI
thread, and avoid optional cleanup in the agent path. Do not trade away the selected speech engine's
accuracy silently to make the timer look better.

Tests should cover terminal-app detection, bypassing cleanup and history, and the invariant that
dictation never submits terminal input. Connector tests should also cover stale or ambiguous targets,
active agent questions/drafts, disconnect/reconnect, and rejected delivery. Android remote-session
tests must cover known-host changes and reconnecting to the same Herdr session after process death.

## Delivery tracking

The implementation is tracked under Kanban epic `TALK-1`, with Android (`TALK-2`), Linux desktop
(`TALK-3`), and latency (`TALK-4`) stories. The initial Android terminal-aware keyboard behavior is
the first slice and SSH/Herdr companion are implemented in the current work branch. Mosh transport,
reconnect after process death, and Linux Herdr awareness remain follow-up work.
