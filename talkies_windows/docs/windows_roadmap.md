# Windows Roadmap (Swift Parity)

Planned/added features to mirror the Swift plugin-based flow:

- Native transcription: whisper.net with GGML models (tiny/base/small/medium/large), selectable model mapping, default ggml-tiny/base path override stored under `%USERPROFILE%\.talkies\models\`.
- Microphone selection: dropdown to choose active capture device.
- LLM enhancement plugin: post-process transcript via Ollama (configurable URL/model); pluggable interface for additional providers.
- TTS plugin: speak the enhanced text via System.Speech; pluggable interface for other engines.
- Text insertion: optional auto-insert of final text into the focused app after transcription.
- Settings persistence: store model/language/mic/LLM/TTS/insert toggles + endpoints in `%USERPROFILE%\.talkies\config.json`.
- UI toggles/fields: enable/disable Enhance, Speak, Insert; configure Ollama endpoint/model; show active plugin status.
- Logging: continue writing to `talkies_win.log` for device selection, transcription, enhancement, TTS, insertion steps.
