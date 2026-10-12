---
title: Windows client
type: platform
status: mixed
tags: [windows, dotnet, wpf, whisper-net, naudio]
sources: [talkies-a4p, talkies-0t9, talkies-xyi, talkies-a18, talkies-64p, talkies-1mn, talkies-czy, talkies-f6b, talkies-8l1, talkies-22z, talkies-snd]
updated: 2026-10-12
---

# Windows client

Code: `windows/Talkies.Windows`. .NET 8 WPF with MVVM, Whisper.net for
transcription, NAudio for capture, Ollama/LM Studio plugins for
[[llm-enhancement]]. Milestone: [[epic-r3-windows-polish]] (`talkies-a4p`, open).

## Built

- **GPU transcription** with CUDA/DirectML, GPU detection, UI controls and error
  handling (`talkies-0t9`). See [[transcription]].
- **Audio quality settings**: sample rate, bit depth, channels, presets, device
  validation, live monitoring (`talkies-xyi`). See [[audio-capture]].
- **Dark mode robustness** pass in PR #84: exception handling, null safety,
  theme detection and contrast fixes (`talkies-64p`).
- CI: orphaned `changes` job dependency removed from the Windows workflow (PR #75, `talkies-22z`).
- MSI/MSIX installer research (`talkies-snd`). See [[release-and-packaging]].

## In progress

- Dark mode improvements (`talkies-a18`, P2).

## Open (all children of `talkies-a4p`)

- Keyboard shortcuts (`talkies-1mn`): Ctrl+N clear, Ctrl+S save VTT, Ctrl+E
  export menu, Space start/stop, Escape stop; hints in tooltips and menus.
- Tooltips on recording, export, model/language, GPU and audio-quality
  controls (`talkies-czy`).
- Application, title-bar, taskbar and tray icons at 16/32/48/256 px (`talkies-f6b`).
- Performance and stability test pass (`talkies-8l1`, P1): 30+ minute
  recordings, 500+ segment transcripts, memory use, GPU stability, background
  hotkey reliability, settings persistence.
