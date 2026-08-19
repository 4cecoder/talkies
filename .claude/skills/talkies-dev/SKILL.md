---
name: talkies-dev
description: Cheat sheet for building, linting, testing, or running any Talkies target (macOS Swift app, Windows .NET WPF app, or Next.js frontend). Use this whenever a task touches mac/, windows/, linux/, or frontend/ and you need the right build/test command or a quick architecture refresher before editing code. mobile/ (Flutter) is deprecated — see its README before working there.

---

# Talkies Dev Cheat Sheet

Talkies is a free, open-source, multi-platform voice transcription app: native macOS, native Windows, native Linux, and a Next.js project site/docs frontend. All transcription is privacy-first and runs on-device — no account, no subscription. A Flutter mobile client exists under `mobile/` but is **deprecated** — not built in CI, not shipped in releases, don't invest new work there without checking with the maintainer first.

## Commands by platform

### macOS (`mac/`) — Swift 6.0 + SwiftUI, macOS 15+
```bash
cd mac
swift build                                        # debug build
swift build -c release                              # release build
swift test                                           # run all tests
swift test --filter TestClass.testMethod             # single test
swift run Talkies                                    # run app
```

### Windows (`windows/Talkies.Windows/`) — .NET 8.0 WPF, MVVM
```bash
cd windows/Talkies.Windows
uv run dotnet build                                              # debug build
uv run dotnet build -c Release                                   # release build
uv run dotnet test                                                # run all tests
uv run dotnet test --filter FullyQualifiedName=...                # single test
uv run dotnet run                                                  # run app
```
Always wrap `dotnet`/`npm` invocations with `uv run` per repo convention.

### Frontend (`frontend/`) — Next.js 16, App Router, React 19, TypeScript, Tailwind v4, bun only (no npm)
```bash
cd frontend
bun install                                            # install deps
bun run dev                                             # dev server (localhost:3000)
bun run build                                           # static export build (output: 'export' -> frontend/out/)
bun run lint                                            # lint
```

### Python CLI tools (`archive/`)
```bash
cd archive
uv run pytest                                           # run all tests
uv run pytest tests/test_[name].py                      # single test
uv run pytest --cov=src                                 # with coverage
```

## Architecture notes

- **macOS**: `Sources/Talkies/`. Uses **WhisperKit** for on-device transcription (Apple Silicon optimized) and **MLX** for ML inference on Metal GPU. Core services: `AudioRecorder.swift`, `TranscriptionService.swift`. Plugin system under `Sources/Talkies/Plugins/` (TTS, image gen, sentiment analysis). Style: `@MainActor` for UI code, Combine for reactive flows, Swift 6 strict concurrency (`nonisolated`), `OSAllocatedUnfairLock` for thread-safe state, prefer `struct` over `class`.
- **Windows**: **Whisper.net** for transcription, **NAudio** for audio capture. LLM enhancement via Ollama/LM Studio in `Plugins/OllamaEnhancer.cs` and `LmStudioProvider.cs`. Main logic in `ViewModels/MainViewModel.cs` (MVVM). Services layer (audio, transcription, settings, hotkeys) in `Services/`. Style: interfaces for service contracts (`IAudioRecorder`), XML doc comments, nullable reference types, `event EventHandler<T>`.
- **Frontend**: project homepage, a live in-browser transcription demo, and onboarding/FAQ docs to help visitors pick a platform — no billing, no accounts required to use the site. Statically exported and deployed to GitHub Pages via `.github/workflows/deploy-pages.yml` (Next.js server features like API routes and middleware don't run in this deploy target — see `frontend/app/page.tsx` and `next.config.ts`). Components in `app/components/`, UI primitives in `app/components/ui/`. Use `cn()` from `@/app/lib/utils` for conditional classes, `forwardRef` + `displayName` for ref-forwarding components, accessibility attributes (`aria-*`, `role`).
- **Linux** (`linux/`): Zig + whisper.cpp, with a GTK4 overlay (`talkies-overlay-gtk`) and global hotkey support on X11/Wayland. Newer and less polished than mac/Windows; see `linux/README.md` and `linux/docs/`.
- **Mobile** (`mobile/`): Flutter app, **deprecated** — no longer actively developed, dropped from CI and release builds. See `mobile/README.md` before touching it.
- Both desktop apps (mac + Windows) support multi-format export (SRT, VTT, TXT) and local LLM enhancement via Ollama.
- Roadmap / open work items live in `docs/ROADMAP.md` (plain markdown, edit via normal PRs — no special tooling). Broader docs index at `docs/README.md`.
- CI builds and tests macOS/Windows/Linux on push (`.github/workflows/ci.yml`); tagged releases (`v*`) build and publish binaries for those three platforms via GitHub Releases (`.github/workflows/release.yml`).

## General principles

- Use `uv run` to wrap `dotnet`/Python commands where the repo convention calls for it (Windows, `archive/`). Frontend uses bun exclusively — never npm/yarn/pnpm.
- Follow existing patterns in each platform directory rather than introducing new ones.
- No secrets in code; write tests for new functionality; keep comments to complex logic only.
