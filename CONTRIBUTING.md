# Contributing to Talkies

Thanks for taking a look! Talkies is a hobby, open-source project — there's no company behind
it, no roadmap deadlines, and no expectation of full-time effort from anyone. All skill levels
are welcome, whether this is your first pull request ever or your five-hundredth.

## Picking something to work on

Talkies is multi-platform, so pick whichever stack you're comfortable in (or want to learn):

- **macOS** (`mac/`) — Swift 6 + SwiftUI, WhisperKit for on-device transcription.
- **Windows** (`windows/`) — .NET 8 WPF, Whisper.net for transcription.
- **Linux** (`linux/`) — Zig + whisper.cpp, X11/Wayland global hotkeys.
- **Mobile** (`mobile/`) — Flutter, targeting iOS & Android.
- **Frontend** (`frontend/`) — Next.js site (this project's homepage, the live browser demo,
  and onboarding docs).

Not sure what's worth doing? Check [`docs/ROADMAP.md`](docs/ROADMAP.md) for the current list of
open and in-progress items across every platform — it's a plain markdown file, so feel free to
add, edit, or claim an item via a normal pull request. Found a bug that's not listed there? Open
a GitHub issue, or just fix it and open a PR.

## Building and testing

The canonical, up-to-date command reference lives in
[`.claude/skills/talkies-dev/SKILL.md`](.claude/skills/talkies-dev/SKILL.md) and
[`AGENTS.md`](AGENTS.md) — rather than duplicate them here (and risk them drifting out of sync),
go there for the exact build/test/run commands for whichever platform you're touching. As a
quick pointer, everything is invoked from that platform's subdirectory (`cd mac`, `cd
windows/Talkies.Windows`, `cd mobile`, `cd frontend`, `cd linux`), and Windows/Python commands
are wrapped with `uv run` per repo convention.

## Code style

See [`AGENTS.md`](AGENTS.md) for per-language style conventions (Swift, C#, TypeScript/React,
Dart, Python). The short version: follow the existing patterns in whichever directory you're
editing rather than introducing a new style, and keep comments to complex logic that actually
needs explaining.

## Opening a pull request

1. Fork the repo and create a branch for your change.
2. Keep the change focused — smaller PRs are easier to review and merge.
3. Make sure the relevant platform's build/tests pass locally (see above).
4. Open a PR with a short description of what changed and why. Screenshots or a quick recording
   are appreciated for UI changes.
5. Be patient — this is maintained on a best-effort basis, so review may take a bit.

## Reporting bugs

Open a GitHub issue with what you expected, what happened instead, your platform/OS version, and
steps to reproduce if you have them. For crash logs or stack traces, paste the relevant portion
rather than a screenshot when you can.

## License

This repository does not currently include a published `LICENSE` file. Check the repository
directly for the latest licensing status before reusing or redistributing the code.

---

Questions, ideas, or just want to say hi? Open an issue or start a discussion on GitHub. Thanks
for being here.
