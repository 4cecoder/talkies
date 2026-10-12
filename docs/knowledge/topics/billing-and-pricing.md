---
title: Billing and pricing
type: topic
status: active
tags: [frontend, stripe, convex, pricing]
sources: [talkies-p4r, talkies-y0a, talkies-ute, talkies-6xs, talkies-2pi, talkies-4ss, talkies-a0i, talkies-oeo, talkies-oxp, talkies-07z, talkies-d5p, talkies-6ou]
updated: 2026-10-12
---

# Billing and pricing

Subscriptions are sold on the [[frontend]] via Stripe, with Convex as the backend.

## Pricing tiers (`talkies-ute`)

Configured in `scripts/stripe_config.toml` after reading the pricing research (`talkies-y0a`):

- Free
- Pro: Monthly, Annual, Lifetime
- Team: Monthly, Annual

Promotion codes (`talkies-4ss`): `TALKIES20` (20% off), `ANNUAL30` (30% off),
`LIFETIME50` (50% off).

## Provisioning

- `scripts/` holds `stripe_config.toml`, `provision_stripe.py`, `.env.example`
  and a README (`talkies-6xs`); `.env.example` documents every price ID (`talkies-2pi`).
- The provisioning script was validated in Stripe test mode; results in
  `TEST_RESULTS.md` (`talkies-a0i`).
- Stripe API version bumped and build fixed (PR #86, `talkies-oeo`).

## Backend and integration

- Convex: `users` and `usage` tables, user CRUD, checkout, billing portal,
  subscription sync, usage tracking with tier limits, webhook handler,
  `ConvexProvider` in the layout (`talkies-oxp`).
- Checkout integrated with Convex (PR #86, `talkies-07z`, blocked by `talkies-oeo`).
- Initial Stripe frontend PR #52 (`talkies-p4r`).
- Checkout modal E2E tests (`talkies-6ou`); see [[frontend-quality-and-testing]].

## In progress

- `talkies-d5p` (P1): finish provisioning updates and frontend/Convex integration.
