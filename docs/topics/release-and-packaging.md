---
title: Release, CI/CD and packaging
type: topic
status: mixed
tags: [ci, release, packaging, installers, auto-update]
sources: [talkies-l8y, talkies-05d, talkies-kf0, talkies-cw5, talkies-0wz, talkies-snd, talkies-nr3, talkies-22z, talkies-s9s, talkies-3sf]
updated: 2026-10-12
---

# Release, CI/CD and packaging

## What happened

- **Consolidation** (`talkies-l8y`, P0): copilot PRs merged around PR #49;
  CI fixes followed in PR #50.
- **Release pipeline and auto-update** (`talkies-05d`, `talkies-kf0`): closed
  as research only. The implementation plans live in **GitHub issues #68 and
  #69**, not in beads.
- **Installers** (`talkies-cw5`, `talkies-0wz`, `talkies-snd`): a `packaging/`
  directory with documentation covering macOS DMG/pkg and Windows MSI/MSIX.
- **Dependabot** (`talkies-nr3`): 5 GitHub Actions bumps merged (#53-57),
  7 frontend/mobile PRs closed.
- **CI fixes**: Windows workflow orphaned `changes` job (PR #75, `talkies-22z`);
  frontend quality job (`talkies-s9s`); mobile CI/CD pipeline (PR #79, `talkies-3sf`).

## Still open

No release bead is open, but the actual release pipeline and auto-updater are
only planned (GitHub #68/#69). Treat that as outstanding.

Related: [[frontend-quality-and-testing]], [[epic-r6-mobile-flutter]].
