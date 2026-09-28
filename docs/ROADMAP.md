# Roadmap

GitHub Issues and milestones are the single source of truth for planned and active engineering
work. This page is an orientation, not a duplicate backlog. Use the issue tracker to see current
owners, labels, discussion, and completion status.

## Active milestones

| Milestone | Focus | Open work |
|---|---|---|
| [R3: Windows polish](https://github.com/4cecoder/talkies/milestone/2) | Validate optional Whisper GPU runtimes on supported physical hardware and finish Windows polish. | [Issue #42](https://github.com/4cecoder/talkies/issues/42) |
| [R4: Shared core & tests](https://github.com/4cecoder/talkies/milestone/1) | Maintain cross-platform contracts, modularize Android by volatility, and add full application offline acceptance. | [Issue #47](https://github.com/4cecoder/talkies/issues/47), [Issue #201](https://github.com/4cecoder/talkies/issues/201) |
| [R5: Open-source release](https://github.com/4cecoder/talkies/milestone/3) | Complete tested offline release gates and publish the first stable desktop release. | [Issue #48](https://github.com/4cecoder/talkies/issues/48) |

## Product status

Talkies is an open-source MIT project with native macOS, Windows, Linux, and Kotlin Android
applications. The website is maintained on a separate branch and deployed as a static GitHub Pages
site. The Flutter prototype is deprecated and stored in [`archive/flutter-prototype/`](../archive/flutter-prototype/README.md).

For shipped behavior and known gaps, read the [feature-gap analysis](product/feature-gap-analysis.md).
For model setup and offline troubleshooting, use the [first-run guide](platforms/first-run-and-troubleshooting.md).
