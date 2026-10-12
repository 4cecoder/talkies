---
title: "Decision: frontend toolchain policy"
type: decision
status: done
tags: [frontend, decision, typescript, bun, prettier]
sources: [talkies-0pf, talkies-lhe, talkies-bn0, talkies-j6e, talkies-b4i, talkies-s9s]
updated: 2026-10-12
---

# Decision: frontend toolchain policy

Decided and enforced 2025-12-17 (PR #87, `talkies-b4i`).

1. **TypeScript is strict and `any` is banned** (`talkies-0pf`); all existing
   `any`s were removed (`talkies-lhe`). Matches the user's global coding
   standards (use proper types, `unknown` or generics).
2. **Prettier is strict** and part of CI (`talkies-bn0`).
3. **Bun is the only package manager**; npm/yarn/pnpm are blocked via
   `packageManager`, a `preinstall` guard and `engine-strict` (`talkies-j6e`).
4. **CI enforces all of it** (`talkies-s9s`).

Note: the repo `CLAUDE.md` still shows `npm` commands for the frontend; per this
decision use the Bun equivalents.

Related: [[frontend-quality-and-testing]], [[frontend]].
