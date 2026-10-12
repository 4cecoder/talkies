---
title: "Incident: force-push recovery (2025-12-19)"
type: decision
status: done
tags: [git, incident, process]
sources: [talkies-68g, talkies-r8w, talkies-96x]
updated: 2026-10-12
---

# Incident: force-push recovery (2025-12-19)

## What happened

A force-push made local `master` and `origin/master` diverge, risking lost
commits (`talkies-68g`, P0).

## Resolution

- Divergence and lost commits analysed (`talkies-68g`).
- Local master merged/rebased onto `origin/master` (`talkies-r8w`, P0).
- Verified that work from **both** sides survived: the Stripe integration
  ([[billing-and-pricing]]) and crash reporting
  ([[analytics-and-crash-reporting]]) (`talkies-96x`).

## Takeaway

Do not force-push shared branches; when it happens, reconcile by merging and
then explicitly check each feature from both histories.
