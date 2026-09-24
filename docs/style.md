# Documentation style

Talkies docs live under `docs/` and use `docs/index.md` as the navigation hub. The root `README.md` stays a short project landing page; platform source folders may retain a small build pointer, but durable user and maintainer guides belong here.

## Page types

- **Tutorials** walk through one task, in order, with a verification step and troubleshooting.
- **Reference** pages list complete options, formats, model requirements, and behavior.
- **Architecture** pages explain boundaries, decisions, and data flow.
- **Product** pages define promises, supported workflows, and measured gaps.
- **Engineering** pages define test, CI, packaging, and release procedures.

Use plain Markdown and relative links ending in `.md`. Keep a single page focused; link related details instead of duplicating them. Every new durable page must be linked from the index or a relevant parent page.

## Voice

- Lead with the answer or the task.
- Prefer short sentences, concrete verbs, commands, and observable outcomes.
- Distinguish current behavior from planned behavior. Never describe an intended feature as shipped.
- Use measured facts and cite primary sources for model and competitor claims.
- Keep product UI friendly and lightly playful; keep technical docs calm and exact.
- Avoid marketing superlatives, filler, unexplained abbreviations, emoji, and exclamation marks.

## Tutorial shape

Use this order when it fits the task:

1. **Why** — what the reader will complete.
2. **Steps** — numbered commands or UI actions.
3. **Verify** — expected output or visible state.
4. **Troubleshooting** — error and direct fix.
5. **Next** — one useful related guide.

Use blockquote callouts with a bold label (`Note`, `Warning`, or `Result`). Include the exact command and expected output when a command is the verification.

## Accuracy checks

- Check every relative link after moving a page.
- State the tested OS, architecture, toolchain, and command for build claims.
- For model pages, include language coverage, quantization, on-disk size, license, source, and whether the model needs network access after download.
- Keep competitor comparisons dated and sourced. Compare documented behavior, not assumed implementation details.
- Mark unverified claims and blockers explicitly.
