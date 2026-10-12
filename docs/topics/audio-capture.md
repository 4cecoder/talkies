---
title: Audio capture
type: topic
status: mixed
tags: [audio, pulseaudio, pipewire, wayland, latency]
sources: [talkies-ukt, talkies-tkv, talkies-e2g, talkies-j8m, talkies-15m, talkies-xyi, talkies-iqr, talkies-5w6]
updated: 2026-10-12
---

# Audio capture

## Linux

- **PulseAudio** recording to WAV with `startRecording`, `stopRecording`,
  `recordChunk`, `getAudioLevel`; `talkies audio` records 5 s with a live level
  display (`talkies-ukt`).
- **Wayland daemon fix** (`talkies-tkv`): the daemon used an external `arecord`
  bash script, which picked the wrong device and added a dependency. Now:
  - internal Zig `AudioRecorder` in both X11 and Wayland modes, using the
    device from config; toggle script only sends WebSocket commands;
  - async PulseAudio stream with pre-initialisation: start in 18.5 ms (was 47 ms);
  - event loop delay 10 ms to 1 ms; chunk size 4096 B (256 ms) to 512 B (16 ms)
    for snappy stop;
  - **350 ms grace period** after stop so trailing words are not cut off.
- **Sound feedback**: "magic" on start, "giggle" on stop, WAV via `aplay`,
  played asynchronously (`talkies-e2g`).

### Backlog
- `talkies-j8m` (P3): native PipeWire `pw_stream` capture with runtime
  detection and PulseAudio fallback, keeping the `AudioRecorder` API. Lists
  `talkies-q21` as a blocker, which does not exist in beads.
- `talkies-15m` (P2): wake word (default "talkies") configured under
  `[wake_word]` in `config.toml` (`enabled`, `word`, `sensitivity`). Candidate
  engines: Porcupine, Vosk, or keyword spotting with Whisper.

## Other platforms

- [[windows]]: configurable sample rate, bit depth, channels and presets with
  device validation (`talkies-xyi`).
- [[macos]]: microphone picker UI (`talkies-iqr`).
- [[mobile]]: Flutter `record` package, now 6.1.2 (`talkies-5w6`).

Related: [[transcription]], [[hotkeys-and-input]].
