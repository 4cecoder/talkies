---
title: Analytics and crash reporting
type: topic
status: mixed
tags: [analytics, crash-reporting, privacy, sentry, posthog]
sources: [talkies-inh, talkies-96x]
updated: 2026-10-12
---

# Analytics and crash reporting

## Research (`talkies-inh`, closed 2025-12-16)

Compared third-party (Sentry, PostHog, Bugsnag) against self-hosting (Vercel
server actions + DB + superadmin dashboard) on privacy, cross-platform
support and cost.

**Recommendation:** self-hosted PostHog as the primary solution to stay
privacy-first, with Sentry as the secondary option. See `CRASHLYTICS.md` at the
repo root.

## Implementation

Crash reporting code exists; it was verified to survive the force-push
recovery alongside the Stripe work (`talkies-96x`, see [[force-push-recovery]]).
The current branch name (`claude/setup-sentry-integration-*`) suggests Sentry
integration is under way, but no bead tracks it yet.

Related: [[release-and-packaging]].
