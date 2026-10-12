---
title: Web frontend (SaaS site)
type: platform
status: mixed
tags: [frontend, nextjs, react, convex, stripe]
sources: [talkies-p4r, talkies-oxp, talkies-07z, talkies-d5p, talkies-0pf, talkies-bn0, talkies-j6e, talkies-b4i, talkies-lhe, talkies-s9s, talkies-bw8, talkies-fgb]
updated: 2026-10-12
---

# Web frontend (SaaS site)

Code: `frontend/`. Next.js 16 App Router, React 19, TypeScript, Tailwind v4.
Landing page, auth modals, pricing, checkout and a dashboard. (A newer
`tanstack-app/` directory exists in the working tree but has no beads.)

## Built

- **Billing**: Stripe integration (PR #52, `talkies-p4r`), Convex backend
  with users/usage tables, checkout, billing portal, subscription sync and
  webhooks (`talkies-oxp`), checkout wired to Convex (PR #86, `talkies-07z`).
  Details: [[billing-and-pricing]].
- **Quality gates**: strict TypeScript with no `any`, strict Prettier, Bun
  only, CI enforcement (`talkies-0pf`, `talkies-bn0`, `talkies-j6e`,
  `talkies-b4i`, `talkies-lhe`, `talkies-s9s`). Rationale: [[frontend-toolchain-policy]].
- **Playwright E2E** for landing, auth, checkout, dashboard, responsive and
  accessibility (PR #85). Details: [[frontend-quality-and-testing]].

## In progress

- `talkies-d5p`: finish Stripe provisioning and frontend integration with Convex.
