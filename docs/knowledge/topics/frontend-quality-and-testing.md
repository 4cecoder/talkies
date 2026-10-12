---
title: Frontend quality and testing
type: topic
status: done
tags: [frontend, typescript, prettier, bun, playwright, ci]
sources: [talkies-0pf, talkies-lhe, talkies-bn0, talkies-j6e, talkies-b4i, talkies-s9s, talkies-bw8, talkies-fgb, talkies-yl5, talkies-lc7, talkies-6ou, talkies-9ht, talkies-jx9]
updated: 2026-10-12
---

# Frontend quality and testing

All closed 2025-12-17. The policy behind these gates is in
[[frontend-toolchain-policy]].

## Static quality gates

- Strict TypeScript, no `any`: rules in `tsconfig.json`, `next.config.ts` and
  `eslint.config.mjs` (`talkies-0pf`); existing `any`s removed from `route.ts`,
  `CheckoutModal.tsx`, `stripe.ts`, `page.tsx` and accessibility tests (`talkies-lhe`).
- Strict Prettier: `.prettierrc.json`, `.prettierignore`, format scripts (`talkies-bn0`).
- Bun only: `packageManager` field, `preinstall` guard, `.npmrc` with `engine-strict` (`talkies-j6e`).
- Combined in PR #87 (`talkies-b4i`).
- CI runs Bun, ESLint, Prettier and the TypeScript build (`talkies-s9s`).

## Playwright E2E (PR #85)

Infrastructure: config, scripts, directory layout (`talkies-bw8`, `talkies-fgb`). Suites:

| Suite | Covers | Bead |
|---|---|---|
| Landing | hero, features, stats, testimonials, pricing, FAQ, nav | `talkies-yl5` |
| Auth modal | login/signup, validation, social auth, a11y | `talkies-lc7` |
| Checkout modal | billing cycles, order summary, errors, visuals | `talkies-6ou` |
| Dashboard | stats, subscription card, recent activity | `talkies-9ht` |
| Responsive + a11y | mobile/tablet/desktop, touch, keyboard, WCAG | `talkies-jx9` |

Related: [[frontend]], [[billing-and-pricing]].
