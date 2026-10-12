---
title: "Decision: GTK4 via hand-written C, not zig-gobject"
type: decision
status: active
tags: [linux, zig, gtk4, decision, interop]
sources: [talkies-0f4, talkies-pmu, talkies-u3x, talkies-79g, talkies-bph, talkies-dpn, talkies-wsy, talkies-0b3, talkies-fkt, talkies-ecn, talkies-cka, talkies-7a2, talkies-9r5, talkies-13d, talkies-ll6]
updated: 2026-10-12
---

# Decision: GTK4 via hand-written C, not zig-gobject

## Context

The [[linux]] client is Zig 0.16. On 2025-12-18 the plan was to build the
settings window, tray icon and recording overlay with zig-gobject's idiomatic
Zig bindings (first Ghostty's pre-built ones, then self-generated).

## What was tried (all closed 2025-12-18)

| Bead | Attempt | Result |
|---|---|---|
| `talkies-0f4`, `talkies-pmu` | Add zig-gobject / gobject_codegen to `build.zig.zon` | Done, but unusable |
| `talkies-u3x` | Point `GIR_PATH` at system `.gir` files | Blocked |
| `talkies-79g` | Generate our own bindings with upstream zig-gobject | Upstream uses removed `@Type` builtin and `std.io.tty`: does not build on 0.16 |
| `talkies-bph` | Rewrite `settings_ui.zig` on zig-gobject | Ghostty's bindings need Zig 0.15.2 |
| `talkies-dpn`, `talkies-wsy`, `talkies-0b3` | Port settings/tray/main to zig-gobject | Deferred |
| `talkies-fkt` | License attribution for zig-gobject | Moot |
| `talkies-ecn`, `talkies-cka` | Native tray (StatusNotifierItem), recording overlay | Blocked by the same issue |

Write-up: `linux/docs/ZIG_016_GTK_BLOCKER.md`. Interim UI was an AGS shell menu.

## Decision

Stay on Zig 0.16 and drive GTK4 through **small hand-written C files**
(`*_gtk.c` / `*_gtk.h`) wrapped by thin Zig modules. Repo commit `2c8c7443`
("remove 120MB Tauri legacy code, champion Zig 0.16 + C interop for GTK")
cemented this. [[daemon-status-gui]] and the [[yap-mode]] window already use
the pattern.

## Consequences and rules of thumb

- Strings crossing into GTK must be NUL-terminated (`dupeZ()`), or widgets end
  up NULL and GTK asserts (`talkies-7a2`).
- Nothing runs a GTK main loop for you; the daemon pumps
  `g_main_context_iteration()` (every 100 ms in YAP), otherwise windows never
  appear (`talkies-9r5`).
- Tray and settings go through raw GTK C and D-Bus: `talkies-13d` (in
  progress). The dictation HUD follows the same approach: `talkies-ll6` (in
  progress). Both are part of [[epic-linux-macos-parity]].
- Revisit zig-gobject only if upstream supports Zig 0.16.
