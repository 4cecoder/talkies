---
title: About this knowledge base
type: overview
status: active
tags: [meta, okf, beads, wiki]
sources: [talkies-b5e, talkies-buh, talkies-pq9, talkies-mf9, talkies-fna, talkies-ll6, talkies-13d, talkies-bw6, talkies-i2u]
updated: 2026-10-12
---

# Talkies knowledge base

This folder is a curated, LLM-navigable wiki of what the Talkies project has
decided, built, and still has open. It was synthesised from the project's
[beads](https://github.com/steveyegge/beads) issue tracker (`.beads/issues.jsonl`,
118 issues) on **2026-10-12**.

Start at [[index]].

## Beads is still the source of truth

These pages are a snapshot. **Beads remains the live tracker**: use `bd list`,
`bd show <id>` and `bd ready` for current state. When a page and beads disagree,
beads wins; update the page (and its `updated` field) when you notice drift.

## Format (OKF: open knowledge format)

Every page is plain Markdown with a YAML frontmatter block:

```yaml
---
title: YAP mode               # human-readable page title
type: topic                   # overview | topic | platform | epic | decision
status: done                  # active | done | open | mixed
tags: [linux, llm, yap]       # free-form, lowercase
sources: [talkies-bw6, ...]   # bead IDs the page was distilled from
updated: 2026-10-12           # last time the page was checked against beads
---
```

| Field | Meaning |
|---|---|
| `type: overview` | Entry points and registers ([[index]], [[project-overview]], [[register]]). |
| `type: platform` | One page per shipped/planned client (Linux, macOS, Windows, mobile, web). |
| `type: topic` | A cross-cutting feature or concern (YAP mode, audio, billing...). |
| `type: epic` | A release milestone / bead epic and its children. |
| `type: decision` | A recorded choice with context, alternatives and consequences. |
| `status: done` | All cited beads are closed. |
| `status: open` | The work is mostly not started. |
| `status: active` | Work is in progress right now. |
| `status: mixed` | Some done, some still open. |

### Links

- A double-bracket wikilink such as `[[index]]` links to another page by its file basename without `.md`.
  Basenames are unique across the whole `docs/` tree, so the folder does not
  need to be spelled out (Obsidian / Foam / most LLM wiki tooling resolve
  this). Example: `[[yap-mode]]` is `docs/topics/yap-mode.md`.
- Bead IDs are written as inline code, e.g. `talkies-i2u`, and resolve via
  `bd show talkies-i2u` or the generated [[register]].

### Layout

```
docs/
  README.md            this file
  index.md             entry point, links every page by area
  project-overview.md  what Talkies is, timeline, status at a glance
  open-work.md         every non-closed bead, ranked
  platforms/           linux, macos, windows, mobile, frontend
  topics/              cross-cutting features and concerns
  decisions/           decision records
  issues/              epic pages + register.md (every bead, one row each)
```

## How it was generated

1. All 118 beads were read (read-only) from `.beads/issues.jsonl`, including
   descriptions, notes, close reasons and `blocks` dependencies. Beads data was
   not modified and `bd sync` was not run.
2. Issues were grouped by platform and feature, then distilled by hand into
   topic pages that say what was decided, what was built, and what is open.
   Every claim cites the bead IDs it came from.
3. `issues/register.md` is a mechanical one-row-per-bead table for traceability.

Beads created on 2026-10-12 (`talkies-b5e`, `-buh`, `-pq9`, `-mf9`, `-fna`,
`-ll6`, `-13d`) belong to the ongoing Linux macOS-parity effort and are
described as in progress; see [[epic-linux-macos-parity]].

## Maintaining

- Add or close beads as normal. Periodically re-read beads and update the
  relevant page's body, `sources`, `status` and `updated`.
- Prefer extending an existing topic page over creating a new one; add new
  pages to [[index]].
