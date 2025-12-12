# Changelog

All notable changes to Whisper CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-25

### Added
- Initial release of Whisper CLI
- Core transcription functionality using Faster Whisper
- Support for multiple Whisper models (tiny, base, small, medium, large)
- Multiple output formats (TXT, SRT, VTT, JSON)
- Batch processing of audio files
- Watch folder functionality for automatic transcription
- Audio recording from microphone
- YouTube video transcription
- AI-powered text improvement (OpenAI, Anthropic, Groq)
- Translation support (Whisper + DeepL)
- Speaker recognition (ElevenLabs, Deepgram)
- Modular architecture with extensible AI services
- TOML-based configuration system
- Rich CLI interface with progress bars
- Comprehensive documentation
- uv-based dependency management

### Features
- **Transcription**: Fast audio-to-text conversion
- **Batch Processing**: Handle multiple files efficiently
- **Real-time Monitoring**: Watch folders for new audio files
- **Recording**: Built-in audio recording capabilities
- **YouTube Integration**: Direct transcription from YouTube URLs
- **AI Enhancement**: Improve transcripts with LLMs
- **Translation**: Multi-language support
- **Speaker Diarization**: Identify different speakers
- **Multiple Formats**: Flexible output options
- **Webhook Integration**: Connect with Make.com, n8n, Zapier
- **GPU Support**: CUDA acceleration for faster processing

### Technical
- Built with Click framework for CLI
- Uses Faster Whisper for optimal performance
- Modular design for easy extension
- Comprehensive test suite
- Type hints and documentation
- Cross-platform compatibility

---

## Development

### Planned for v0.2.0
- [ ] Custom GGML model support
- [ ] Advanced speaker diarization
- [ ] Video player integration
- [ ] Podcast episode detection
- [ ] Cloud storage integration
- [ ] REST API server mode
- [ ] GUI interface option
- [ ] Plugin system for extensions

### Planned for v0.3.0
- [ ] Real-time streaming transcription
- [ ] Multi-language model support
- [ ] Advanced VAD options
- [ ] Custom vocabulary/training
- [ ] Integration with more AI services
- [ ] Mobile app companion

---

For more information about upcoming features, see the [GitHub Issues](https://github.com/your-repo/issues).