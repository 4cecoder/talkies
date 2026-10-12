---
title: Bead issue register
type: overview
status: mixed
tags: [beads, register, traceability]
sources: [talkies-05d, talkies-07z, talkies-0b3, talkies-0f4, talkies-0o6, talkies-0pf, talkies-0sd, talkies-0t9, talkies-0ub, talkies-0wz, talkies-0ye, talkies-13d, talkies-15m, talkies-1mn, talkies-22z, talkies-2kh, talkies-2pi, talkies-3bp, talkies-3hv, talkies-3sf, talkies-4ss, talkies-5dq, talkies-5w6, talkies-64p, talkies-68g, talkies-6m4, talkies-6ou, talkies-6ww, talkies-6xs, talkies-79g, talkies-7a2, talkies-7k1, talkies-8hz, talkies-8l1, talkies-96x, talkies-9c3, talkies-9ht, talkies-9jn, talkies-9r5, talkies-a0i, talkies-a18, talkies-a4p, talkies-b4i, talkies-b5e, talkies-bbk, talkies-bn0, talkies-bph, talkies-buh, talkies-bw6, talkies-bw8, talkies-cdd, talkies-cka, talkies-clp, talkies-coa, talkies-cw5, talkies-czy, talkies-d5p, talkies-d9g, talkies-di1, talkies-dlg, talkies-dpn, talkies-dvl, talkies-e2g, talkies-e59, talkies-e5y, talkies-ecn, talkies-f6b, talkies-fgb, talkies-fkt, talkies-fna, talkies-ggw, talkies-h98, talkies-hzo, talkies-i2u, talkies-inh, talkies-iqr, talkies-j6e, talkies-j8m, talkies-jow, talkies-jx9, talkies-kbu, talkies-kf0, talkies-kys, talkies-l8y, talkies-lc7, talkies-lhe, talkies-ll6, talkies-mf9, talkies-mt8, talkies-ndz, talkies-nr3, talkies-o1j, talkies-oeo, talkies-oxp, talkies-p4r, talkies-pfg, talkies-pmu, talkies-pq9, talkies-qm0, talkies-r8w, talkies-rd6, talkies-rdy, talkies-s9s, talkies-snd, talkies-spz, talkies-tkv, talkies-u3x, talkies-ukt, talkies-urc, talkies-ute, talkies-uu2, talkies-v1u, talkies-wsy, talkies-xyi, talkies-xzx, talkies-y0a, talkies-yl5, talkies-zgf]
updated: 2026-10-12
---

# Bead issue register

Flat, generated list of every bead in `.beads/issues.jsonl` as of 2026-10-12 (118 issues). Use it to resolve a bead ID cited on a topic page. For synthesis, start at [[index]]. Beads remains the live tracker; see [[README]].

Status legend: `open`, `in_progress`, `closed`. Priority P0 (highest) to P3.

| ID | Status | Type | P | Created | Closed | Title | Blocked by | Close reason |
|---|---|---|---|---|---|---|---|---|
| `talkies-05d` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | Implement release management CI/CD pipeline |  | Research complete, GitHub issues #68 and #69 created with comprehensive implementation plans |
| `talkies-07z` | closed | feature | P1 | 2025-12-17 | 2025-12-17 | Integrate Stripe checkout with ConvexDB backend | talkies-oeo | Frontend integration fixes completed in PR #86 |
| `talkies-0b3` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Re-enable tray/settings integration in main.zig |  | zig-gobject integration more complex than expected - requires deeper study of Ghostty setup. Shell-based menu via AGS already works well. Deferring GTK bindi... |
| `talkies-0f4` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Add zig-gobject dependency to build.zig.zon |  | Closed |
| `talkies-0o6` | open | task | P2 | 2025-12-19 |  | Implement YAP session auto-save and recovery |  |  |
| `talkies-0pf` | closed | feature | P1 | 2025-12-17 | 2025-12-17 | Enforce strict TypeScript (no any allowed) |  | Completed: Added strict TypeScript rules to tsconfig.json, next.config.ts, and eslint.config.mjs |
| `talkies-0sd` | closed | bug | P1 | 2025-12-19 | 2025-12-19 | Fix daemon accepting recording commands during YAP mode |  | Implemented in commit a1a2f4c - navigable revision viewer with prev/next buttons and state guard to prevent recording during YAP mode |
| `talkies-0t9` | closed | feature | P2 | 2025-12-16 | 2025-12-16 | [R3/Windows] GPU Transcription (CUDA/DirectML) |  | Completed implementation of GPU transcription with CUDA/DirectML support including enhanced GPU detection, UI controls, Whisper.net runtime integration, comp... |
| `talkies-0ub` | closed | feature | P1 | 2025-12-19 | 2025-12-19 | Enable continuous recording in YAP mode to append transcriptions |  | Implemented in commit dcc3339 - continuous recording now appends to sandbox in YAP mode |
| `talkies-0wz` | closed | task | P1 | 2025-12-16 | 2025-12-16 | Research macOS installer packaging (DMG, pkg) |  | Packaging documentation created and committed |
| `talkies-0ye` | closed | epic | P1 | 2025-12-16 | 2025-12-16 | [R1] Cross-Platform Parity Spec |  | Created CROSS_PLATFORM_SPEC.md with full feature matrix, shortcuts, settings schema |
| `talkies-13d` | open | feature | P1 | 2026-10-12 |  | [Linux] Settings window + tray on raw GTK C / D-Bus |  |  |
| `talkies-15m` | open | feature | P2 | 2025-12-27 |  | [Linux] Add wake word detection with configurable trigger word |  |  |
| `talkies-1mn` | open | feature | P2 | 2025-12-16 |  | Add keyboard shortcuts to Windows UI | talkies-a4p |  |
| `talkies-22z` | closed | bug | P1 | 2025-12-17 | 2025-12-17 | Fix PR #75: Remove orphaned 'changes' job dependency from Windows CI |  | CI fix complete, all checks passing |
| `talkies-2kh` | closed | task | P1 | 2025-12-19 | 2025-12-19 | Integrate daemon status window with main.zig daemon loop |  | Integrated daemon status window into main.zig daemon loop with live updates for all state transitions, logging, and GTK event processing |
| `talkies-2pi` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Create environment template with price IDs |  | Created .env.example with all price ID placeholders and comprehensive documentation |
| `talkies-3bp` | closed | feature | P1 | 2025-12-19 | 2025-12-19 | Make YAP mode non-blocking for continuous recording |  | Implemented in commit cb9ba18. YAP mode is now non-blocking with persistent state, allowing continuous recording and appending. Revision viewer now has prev/... |
| `talkies-3hv` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Clarify implemented vs planned features in diagram | talkies-coa | Closed |
| `talkies-3sf` | in_progress | epic | P1 | 2025-12-16 |  | [R6/Mobile] Flutter Feature Parity & CI/CD Plan |  |  |
| `talkies-4ss` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Add promotion codes to configuration |  | Added 3 promotion codes: TALKIES20 (20% off), ANNUAL30 (30% off), LIFETIME50 (50% off) |
| `talkies-5dq` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Add command-line flag to show/hide daemon status window |  | Added show_status_gui config option (default: true) to enable/disable daemon status window |
| `talkies-5w6` | closed | bug | P1 | 2025-12-17 | 2025-12-17 | Upgrade record package to v6.1.2 for Android namespace fix |  | Completed: record package upgraded to v6.1.2, API parameter fixed, commit pushed, and CI triggered |
| `talkies-64p` | closed | bug | P1 | 2025-12-16 | 2025-12-17 | Verify Windows dark mode consistency | talkies-a4p |  |
| `talkies-68g` | closed | bug | P0 | 2025-12-19 | 2025-12-19 | Recover from force-push: analyze divergence and lost commits |  | Closed |
| `talkies-6m4` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Add platform implementation status to diagram (macOS/Windows/Linux/Mobile/Frontend) | talkies-coa | Closed |
| `talkies-6ou` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Create checkout modal E2E tests |  | Created checkout modal E2E tests covering billing cycles, order summary, error handling, and visual design |
| `talkies-6ww` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Generate updated PNG from improved Mermaid diagram | talkies-coa | Closed |
| `talkies-6xs` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Create scripts directory and Stripe configuration files |  | Created scripts directory with stripe_config.toml, provision_stripe.py, .env.example, and README.md |
| `talkies-79g` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Generate custom zig-gobject bindings for Talkies |  | Upstream zig-gobject incompatible with Zig 0.16.0 - uses deprecated @Type builtin and std.io.tty. Ghostty likely maintains patched version. Shell-based AGS m... |
| `talkies-7a2` | closed | bug | P1 | 2025-12-19 | 2025-12-19 | Fix GTK status window widget NULL pointer errors |  | Fixed by adding null terminators to all C string parameters via dupeZ() |
| `talkies-7k1` | closed | bug | P1 | 2025-12-17 | 2025-12-17 | Update audio service to use record v5.2.0 API |  | Updated AudioRecorderService to use record v5.2.0 API with RecordConfig wrapper. Changes committed and pushed to feature/mobile-ui-redesign. Mobile CI workfl... |
| `talkies-8hz` | closed | feature | P1 | 2025-12-19 | 2025-12-19 | Implement navigable revision viewer in YAP window |  | Implemented in commit cb9ba18. YAP mode is now non-blocking with persistent state, allowing continuous recording and appending. Revision viewer now has prev/... |
| `talkies-8l1` | open | bug | P1 | 2025-12-16 |  | Test Windows app performance and stability | talkies-a4p |  |
| `talkies-96x` | closed | task | P1 | 2025-12-19 | 2025-12-19 | Verify crash reporting and analytics features are preserved |  | Force-push recovery complete. All features preserved from both branches: Stripe integration + crash reporting. |
| `talkies-9c3` | closed | bug | P1 | 2025-12-19 | 2025-12-19 | Fix YAP refinement: reduce capitalization and formal tone |  | Fixed in commit abb7d46. Updated system prompt to discourage over-capitalization and use natural conversational tone. Changed button from 'Paste' to 'Copy'. |
| `talkies-9ht` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Create dashboard page E2E tests |  | Created dashboard page E2E tests covering stats, subscription card, recent activity, and interactions |
| `talkies-9jn` | closed | feature | P0 | 2025-12-19 | 2025-12-19 | Create GTK UI for YAP mode |  | Implemented 3-part YAP GUI with context, sandbox, and history sections |
| `talkies-9r5` | closed | bug | P0 | 2025-12-19 | 2025-12-19 | YAP GUI window not appearing after successful LLM refinement |  | Fixed by adding GTK event loop processing. Window now calls g_main_context_iteration() every 100ms to process events and render correctly. |
| `talkies-a0i` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Test provisioning script in test mode |  | Script tested successfully - configuration valid, dependencies installed, TEST_RESULTS.md documents validation |
| `talkies-a18` | in_progress | feature | P2 | 2025-12-16 |  | [R3/Windows] Dark Mode Improvements |  |  |
| `talkies-a4p` | open | epic | P2 | 2025-12-16 |  | [R3] Windows Polish Milestone | talkies-0ye |  |
| `talkies-b4i` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Enforce strict TypeScript, Prettier, and Bun usage in frontend |  | PR #87 merged successfully |
| `talkies-b5e` | open | epic | P1 | 2026-10-12 |  | [Linux] macOS parity epic |  |  |
| `talkies-bbk` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Create documentation (README, ARCHITECTURE, BUILD) |  | Created complete documentation: README.md (user guide), ARCHITECTURE.md (design details), BUILD.md (build instructions) |
| `talkies-bn0` | closed | feature | P1 | 2025-12-17 | 2025-12-17 | Configure Prettier to be strict |  | Completed: Added .prettierrc.json, .prettierignore, and format scripts |
| `talkies-bph` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Implement native GTK settings window using zig-gobject |  | BLOCKED: Ghostty's zig-gobject bindings require Zig 0.15.2, incompatible with our Zig 0.16.0. Zig 0.16 removed @Type builtin which breaks pre-built bindings.... |
| `talkies-buh` | open | feature | P1 | 2026-10-12 |  | [Linux] Config: mirror macOS ollama/lm_studio/enhancer keys in TOML |  |  |
| `talkies-bw6` | closed | feature | P1 | 2025-12-19 | 2025-12-19 | Implement YAP mode: conversational LLM refinement for transcriptions | talkies-agm, talkies-18k, talkies-ih9, talkies-jow, talkies-d9g | YAP mode fully implemented: Ollama integration, 3-part GUI (context/sandbox/history), refinement workflow, session management, all dependencies complete |
| `talkies-bw8` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Set up Playwright E2E testing infrastructure |  | Playwright E2E testing infrastructure set up successfully with config, test scripts, and directory structure |
| `talkies-cdd` | closed | bug | P1 | 2025-12-17 | 2025-12-17 | Fix mobile Android namespace error in record package |  | Completed: Upgraded record package from v4.4.0 to v5.2.0 to fix Android namespace error. Commit: d07d416 |
| `talkies-cka` | closed | feature | P2 | 2025-12-18 | 2025-12-18 | Create visual recording overlay with GTK |  | BLOCKED by same Zig 0.16 / zig-gobject incompatibility as talkies-bph. See docs/ZIG_016_GTK_BLOCKER.md for details. |
| `talkies-clp` | closed | epic | P1 | 2025-12-16 | 2025-12-16 | [R2] macOS Catch-Up Milestone | talkies-0ye | R2 macOS Catch-Up complete - PR #51 covers all features |
| `talkies-coa` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Update business architecture diagram with accurate implementation status |  | Closed |
| `talkies-cw5` | closed | task | P1 | 2025-12-16 | 2025-12-16 | Create packaging/ directory with build scripts |  | Packaging documentation created and committed |
| `talkies-czy` | open | feature | P2 | 2025-12-16 |  | Add tooltips to Windows UI controls | talkies-a4p |  |
| `talkies-d5p` | in_progress | feature | P1 | 2025-12-16 |  | Update Stripe provisioning and integrate with frontend (ConvexDB) |  |  |
| `talkies-d9g` | closed | task | P1 | 2025-12-19 | 2025-12-19 | Add WebSocket/terminal UI for YAP mode interaction |  | Completed by parallel subagents. Session manager and WebSocket/terminal UI fully integrated. |
| `talkies-di1` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Set up Zig project structure and build.zig |  | Completed Zig project structure setup. Build system working with all module skeletons created (main, audio, whisper, clipboard, input, config, utils). Tests ... |
| `talkies-dlg` | closed | feature | P2 | 2025-12-19 | 2025-12-19 | Add interactive clarification step to YAP refinement workflow |  | Closed |
| `talkies-dpn` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Update settings_ui.zig to use zig-gobject imports |  | zig-gobject integration more complex than expected - requires deeper study of Ghostty setup. Shell-based menu via AGS already works well. Deferring GTK bindi... |
| `talkies-dvl` | closed | feature | P2 | 2025-12-19 | 2025-12-19 | Apply Tokyo Night dark theme to all GTK4 windows |  | Implemented in commit d2458d2. Applied Tokyo Night color scheme to YAP Mode and Daemon Status windows via GTK CSS provider. |
| `talkies-e2g` | closed | feature | P2 | 2025-12-19 | 2025-12-19 | Add audio feedback sounds for recording start/stop |  | Closed |
| `talkies-e59` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | [R2/macOS] Persistent Settings |  | PRs created: #51 (macOS features), #52 (Stripe) |
| `talkies-e5y` | closed | bug | P1 | 2025-12-17 | 2025-12-17 | Fix Flutter mobile audio service for record v4.4.0 API |  | Fixed AudioRecorder to Record class and RecordConfig parameters to match v4.4.0 API |
| `talkies-ecn` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Add native GTK system tray icon |  | BLOCKED by same Zig 0.16 / zig-gobject incompatibility as talkies-bph. See docs/ZIG_016_GTK_BLOCKER.md for details. |
| `talkies-f6b` | open | feature | P2 | 2025-12-16 |  | Add Windows application icon and window icon | talkies-a4p |  |
| `talkies-fgb` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Add Playwright E2E tests for frontend |  | PR #85 successfully merged after rebasing on updated master |
| `talkies-fkt` | closed | task | P2 | 2025-12-18 | 2025-12-18 | Update THIRD_PARTY_LICENSES.md with zig-gobject attribution |  | zig-gobject integration more complex than expected - requires deeper study of Ghostty setup. Shell-based menu via AGS already works well. Deferring GTK bindi... |
| `talkies-fna` | open | feature | P1 | 2026-10-12 |  | [Linux] Auto push-to-talk/toggle hotkey (150ms threshold) X11+Wayland |  |  |
| `talkies-ggw` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | [R2/macOS] LLM Enhancement Modes |  | LLM Enhancement Modes already in Ollama/LM Studio plugins |
| `talkies-h98` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | [R2/macOS] Global Hotkeys |  | Global hotkeys already implemented via NSEvent monitoring |
| `talkies-hzo` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Implement clipboard and input simulation |  | Completed clipboard and text insertion implementation for Linux Zig. Enhanced clipboard.zig with Wayland/X11 detection, get/copy methods for save/restore. En... |
| `talkies-i2u` | open | feature | P1 | 2025-12-19 |  | Implement daemon status GUI with live logs and error indicators |  |  |
| `talkies-inh` | closed | task | P2 | 2025-12-16 | 2025-12-16 | Research analytics and crash reporting options |  | Completed comprehensive research on analytics and crash reporting options. Created detailed analysis document covering third-party solutions (Sentry, PostHog... |
| `talkies-iqr` | closed | feature | P2 | 2025-12-16 | 2025-12-16 | [R2/macOS] Microphone Picker UI |  | PRs created: #51 (macOS features), #52 (Stripe) |
| `talkies-j6e` | closed | feature | P1 | 2025-12-17 | 2025-12-17 | Enforce Bun usage (ban npm/yarn/pnpm) |  | Completed: Added packageManager field, preinstall script, and .npmrc with engine-strict |
| `talkies-j8m` | open | feature | P3 | 2025-12-27 |  | [Linux] Add native PipeWire API support | talkies-q21 |  |
| `talkies-jow` | closed | task | P1 | 2025-12-19 | 2025-12-19 | Integrate YAP session manager into daemon workflow |  | Completed by parallel subagents. Session manager and WebSocket/terminal UI fully integrated. |
| `talkies-jx9` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Add responsive and accessibility E2E tests |  | Created comprehensive responsive and accessibility E2E tests covering mobile/tablet/desktop, touch interactions, keyboard navigation, and WCAG compliance |
| `talkies-kbu` | closed | task | P1 | 2025-12-19 | 2025-12-19 | Wire daemon status window to WebSocket state changes |  | Status window now wired to WebSocket state changes via daemon_state.getState() in event loop |
| `talkies-kf0` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | Research and implement auto-update system |  | Research complete, GitHub issues #68 and #69 created with comprehensive implementation plans |
| `talkies-kys` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | [R2/macOS] Ollama Provider Integration |  | Ollama already implemented in OllamaPlugin.swift |
| `talkies-l8y` | closed | task | P0 | 2025-12-16 | 2025-12-16 | [PR-49] Merge consolidated copilot PRs + CI/CD |  | CI fixes PR #50 created |
| `talkies-lc7` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Create auth modal E2E tests |  | Created auth modal E2E tests covering login/signup forms, validation, social auth, and accessibility |
| `talkies-lhe` | closed | bug | P1 | 2025-12-17 | 2025-12-17 | Fix all existing any types in codebase |  | Completed: Fixed all any types in route.ts, CheckoutModal.tsx, stripe.ts, page.tsx, and accessibility tests |
| `talkies-ll6` | open | feature | P1 | 2026-10-12 |  | [Linux] Floating dictation HUD (GTK4 C) with pipeline stages + waveform |  |  |
| `talkies-mf9` | open | feature | P1 | 2026-10-12 |  | [Linux] Clipboard restore after paste |  |  |
| `talkies-mt8` | closed | feature | P1 | 2025-12-16 | 2025-12-16 | [R2/macOS] LM Studio Provider Integration |  | PRs created: #51 (macOS features), #52 (Stripe) |
| `talkies-ndz` | closed | feature | P2 | 2025-12-16 | 2025-12-16 | [R2/macOS] Push-to-Talk |  | Push-to-talk already implemented with Right Option key |
| `talkies-nr3` | closed | task | P3 | 2025-12-16 | 2025-12-16 | Merge dependabot PRs for action updates |  | Merged 5 GitHub Actions PRs (#53-57), closed 7 frontend/mobile PRs |
| `talkies-o1j` | closed | feature | P2 | 2025-12-16 | 2025-12-16 | [R2/macOS] Provider/Model Discovery |  | Provider/model discovery implemented in Ollama and LM Studio plugins |
| `talkies-oeo` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Update Stripe provisioning with Talkies pricing tiers |  | Stripe API version updated and build fixed in PR #86 |
| `talkies-oxp` | closed | feature | P2 | 2025-12-17 | 2025-12-17 | ConvexDB Infrastructure Setup for Stripe Integration |  | Successfully set up ConvexDB infrastructure with database schema (users, usage tables), user CRUD operations, Stripe integration functions (checkout, billing... |
| `talkies-p4r` | closed | feature | P2 | 2025-12-16 | 2025-12-16 | [Frontend] Stripe Integration |  | PRs created: #51 (macOS features), #52 (Stripe) |
| `talkies-pfg` | closed | feature | P1 | 2025-12-19 | 2025-12-19 | Implement daemon status monitor GUI |  | Core daemon status GUI complete with live logs, status indicators, and GTK event processing. Remaining features tracked separately: talkies-v1u (log intercep... |
| `talkies-pmu` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Add gobject_codegen dependency to build.zig.zon |  | Closed |
| `talkies-pq9` | open | feature | P1 | 2026-10-12 |  | [Linux] LLM enhance pipeline: Ollama + LM Studio with 5 macOS presets |  |  |
| `talkies-qm0` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Add whisper.cpp C FFI bindings |  | Implemented complete whisper.cpp C FFI integration with loadModel(), transcribe(), getSegments(), and downloadModel(). Includes comprehensive documentation a... |
| `talkies-r8w` | closed | task | P0 | 2025-12-19 | 2025-12-19 | Merge or rebase local master onto origin/master |  | Force-push recovery complete. All features preserved from both branches: Stripe integration + crash reporting. |
| `talkies-rd6` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Add accurate tech stack details for each platform | talkies-coa | Closed |
| `talkies-rdy` | closed | bug | P0 | 2025-12-19 | 2025-12-19 | Fix Ollama streaming EndOfStream error in YAP mode |  | Fixed by migrating to Zig 0.16 HTTP API (allocRemaining instead of readAlloc) |
| `talkies-s9s` | closed | feature | P1 | 2025-12-17 | 2025-12-17 | Add CI enforcement for frontend quality checks |  | Completed: Added frontend quality checks to CI workflow with Bun, ESLint, Prettier, and TypeScript build |
| `talkies-snd` | closed | task | P1 | 2025-12-16 | 2025-12-16 | Research Windows installer packaging (MSI, MSIX) |  | Packaging documentation created and committed |
| `talkies-spz` | closed | bug | P2 | 2025-12-19 | 2025-12-19 | Fix Ollama status showing 'out of commission' in debug GUI |  | Closed |
| `talkies-tkv` | closed | bug | P1 | 2025-12-19 | 2025-12-19 | Fix Wayland audio recording to use internal Zig AudioRecorder instead of external arecord script |  | Implemented async PulseAudio stream with pre-initialization. Recording now starts instantly (18.5ms vs 47ms). Added 350ms grace period for trailing words. Me... |
| `talkies-u3x` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Set up GIR_PATH for system GIR files |  | Upstream zig-gobject incompatible with Zig 0.16.0 - uses deprecated @Type builtin and std.io.tty. Ghostty likely maintains patched version. Shell-based AGS m... |
| `talkies-ukt` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Implement audio recording with PulseAudio |  | Implemented PulseAudio audio recording with WAV file support. Added startRecording(), stopRecording(), recordChunk(), and getAudioLevel() methods. All unit t... |
| `talkies-urc` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Add configuration file management |  | Implemented complete TOML config management with load/save/validation. Supports all config fields (model, language, threads, auto_paste, export_format). Crea... |
| `talkies-ute` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Update stripe_config.toml with Talkies pricing |  | stripe_config.toml updated with all Talkies pricing tiers (Free, Pro Monthly/Annual/Lifetime, Team Monthly/Annual) |
| `talkies-uu2` | closed | task | P2 | 2025-12-19 | 2025-12-19 | Redesign YAP revision history as navigable viewer |  | Implemented in commit a1a2f4c - navigable revision viewer with prev/next buttons and state guard to prevent recording during YAP mode |
| `talkies-v1u` | open | task | P1 | 2025-12-19 |  | Add log interception to route stdout/stderr to status GUI |  |  |
| `talkies-wsy` | closed | task | P1 | 2025-12-18 | 2025-12-18 | Update tray.zig to use zig-gobject imports |  | zig-gobject integration more complex than expected - requires deeper study of Ghostty setup. Shell-based menu via AGS already works well. Deferring GTK bindi... |
| `talkies-xyi` | closed | feature | P2 | 2025-12-16 | 2025-12-16 | [R3/Windows] Audio Quality Settings |  | Implemented comprehensive audio quality settings with configurable sample rates, bit depths, channels, preset configurations, device validation, and real-tim... |
| `talkies-xzx` | open | feature | P3 | 2025-12-19 |  | Add session export and history viewer |  |  |
| `talkies-y0a` | closed | task | P1 | 2025-12-17 | 2025-12-17 | Read pricing research documents |  | Completed reading all pricing research documents |
| `talkies-yl5` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Create landing page E2E tests |  | Created comprehensive landing page E2E tests covering hero, features, stats, testimonials, pricing, FAQ, and navigation |
| `talkies-zgf` | closed | task | P2 | 2025-12-17 | 2025-12-17 | Build CLI interface and arg parsing |  | CLI interface completed with all commands implemented: quick, record, models, config, audio, help |

## Dangling dependencies

- `talkies-bw6` (YAP mode) lists `talkies-agm`, `talkies-18k`, `talkies-ih9` as blockers; those beads were deleted (recorded in `.beads/deletions.jsonl`).
- `talkies-j8m` (PipeWire) lists `talkies-q21` as a blocker; that bead exists in neither issues nor deletions.
