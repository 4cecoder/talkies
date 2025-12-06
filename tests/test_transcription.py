"""
Tests for transcription functionality
"""

import pytest
import tempfile
import json
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.transcription import transcribe_file, save_transcript, add_speaker_labels


class MockSegment:
    """Mock segment for Whisper transcription"""
    def __init__(self, start, end, text):
        self.start = start
        self.end = end
        self.text = text


class MockInfo:
    """Mock info object for Whisper transcription"""
    def __init__(self, language="en"):
        self.language = language
        self.duration = 10.0  # Default duration


def test_transcribe_file_basic(mocker):
    """Test basic file transcription"""
    # Create a temporary audio file
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_path = Path(f.name)
        f.write(b"fake audio data")

    try:
        # Mock WhisperModel
        mock_model = Mock()
        mock_segments = [
            MockSegment(0.0, 2.0, "Hello"),
            MockSegment(2.0, 4.0, " world")
        ]
        mock_info = MockInfo("en")
        mock_model.transcribe.return_value = (mock_segments, mock_info)

        mock_faster_whisper = Mock()
        mock_faster_whisper.WhisperModel.return_value = mock_model

        with patch('whisper_cli.transcription._ensure_model_ready'):
            with patch.dict('sys.modules', {'faster_whisper': mock_faster_whisper}):
                result = transcribe_file(audio_path, model="base", config={})

        assert "text" in result
        assert "segments" in result
        assert "language" in result
        assert result["text"] == "Hello world"
        assert len(result["segments"]) == 2
        assert result["language"] == "en"
    finally:
        audio_path.unlink(missing_ok=True)


def test_transcribe_file_with_language(mocker):
    """Test transcription with specified language"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_path = Path(f.name)
        f.write(b"fake audio data")

    try:
        mock_model = Mock()
        mock_segments = [MockSegment(0.0, 1.0, "Bonjour")]
        mock_info = MockInfo("fr")
        mock_model.transcribe.return_value = (mock_segments, mock_info)

        mock_faster_whisper = Mock()
        mock_faster_whisper.WhisperModel.return_value = mock_model

        with patch('whisper_cli.transcription._ensure_model_ready'):
            with patch.dict('sys.modules', {'faster_whisper': mock_faster_whisper}):
                result = transcribe_file(audio_path, model="base", language="fr", config={})

        assert result["language"] == "fr"
        mock_model.transcribe.assert_called_once()
        call_args = mock_model.transcribe.call_args
        assert call_args[1]["language"] == "fr"
    finally:
        audio_path.unlink(missing_ok=True)


def test_transcribe_file_with_translate(mocker):
    """Test transcription with translation"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_path = Path(f.name)
        f.write(b"fake audio data")

    try:
        mock_model = Mock()
        mock_segments = [MockSegment(0.0, 1.0, "Hello")]
        mock_info = MockInfo("en")
        mock_model.transcribe.return_value = (mock_segments, mock_info)

        mock_faster_whisper = Mock()
        mock_faster_whisper.WhisperModel.return_value = mock_model

        with patch('whisper_cli.transcription._ensure_model_ready'):
            with patch.dict('sys.modules', {'faster_whisper': mock_faster_whisper}):
                result = transcribe_file(audio_path, model="base", translate="en", config={})

        mock_model.transcribe.assert_called_once()
        call_args = mock_model.transcribe.call_args
        assert call_args[1]["task"] == "translate"
    finally:
        audio_path.unlink(missing_ok=True)


def test_transcribe_file_with_speakers(mocker):
    """Test transcription with speaker recognition"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_path = Path(f.name)
        f.write(b"fake audio data")

    try:
        mock_model = Mock()
        mock_segments = [MockSegment(0.0, 1.0, "Hello")]
        mock_info = MockInfo("en")
        mock_info.duration = 1.0
        mock_model.transcribe.return_value = (mock_segments, mock_info)

        mock_faster_whisper = Mock()
        mock_faster_whisper.WhisperModel.return_value = mock_model

        with patch('whisper_cli.transcription._ensure_model_ready'):
            with patch.dict('sys.modules', {'faster_whisper': mock_faster_whisper}):
                with patch('whisper_cli.transcription.add_speaker_labels') as mock_speaker:
                    mock_speaker.return_value = {"text": "Hello", "segments": [], "language": "en", "speakers": []}
                    result = transcribe_file(audio_path, model="base", speakers=True, config={})

        mock_speaker.assert_called_once()
    finally:
        audio_path.unlink(missing_ok=True)


def test_transcribe_file_with_config_device(mocker):
    """Test transcription with device from config"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_path = Path(f.name)
        f.write(b"fake audio data")

    try:
        mock_model = Mock()
        mock_segments = [MockSegment(0.0, 1.0, "Hello")]
        mock_info = MockInfo("en")
        mock_info.duration = 1.0
        mock_model.transcribe.return_value = (mock_segments, mock_info)

        config = {"whisper": {"device": "cuda", "compute_type": "float16"}}

        mock_faster_whisper = Mock()
        mock_faster_whisper.WhisperModel.return_value = mock_model

        with patch('whisper_cli.transcription._ensure_model_ready'):
            with patch.dict('sys.modules', {'faster_whisper': mock_faster_whisper}):
                transcribe_file(audio_path, model="base", config=config)

        mock_faster_whisper.WhisperModel.assert_called_once_with(
            "base", device="cuda", compute_type="float16"
        )
    finally:
        audio_path.unlink(missing_ok=True)


def test_save_transcript_txt():
    """Test saving transcript as TXT format"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        output_path = Path(f.name)

    try:
        result = {"text": "Hello world", "segments": [], "language": "en"}
        save_transcript(result, output_path, "txt")

        assert output_path.exists()
        with open(output_path, 'r') as f:
            content = f.read()
        assert content == "Hello world"
    finally:
        output_path.unlink(missing_ok=True)


def test_save_transcript_json():
    """Test saving transcript as JSON format"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        output_path = Path(f.name)

    try:
        result = {
            "text": "Hello world",
            "segments": [{"start": 0.0, "end": 1.0, "text": "Hello world"}],
            "language": "en"
        }
        save_transcript(result, output_path, "json")

        assert output_path.exists()
        with open(output_path, 'r') as f:
            loaded = json.load(f)
        assert loaded["text"] == "Hello world"
        assert len(loaded["segments"]) == 1
    finally:
        output_path.unlink(missing_ok=True)


def test_save_transcript_srt():
    """Test saving transcript as SRT format"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.srt', delete=False) as f:
        output_path = Path(f.name)

    try:
        result = {
            "text": "Hello world",
            "segments": [
                {"start": 0.0, "end": 2.5, "text": "Hello"},
                {"start": 2.5, "end": 5.0, "text": "world"}
            ],
            "language": "en"
        }
        save_transcript(result, output_path, "srt")

        assert output_path.exists()
        content = output_path.read_text()
        assert "1\n" in content
        assert "00:00:00,000 --> 00:00:02,500" in content
        assert "Hello" in content
    finally:
        output_path.unlink(missing_ok=True)


def test_save_transcript_vtt():
    """Test saving transcript as VTT format"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.vtt', delete=False) as f:
        output_path = Path(f.name)

    try:
        result = {
            "text": "Hello world",
            "segments": [
                {"start": 0.0, "end": 2.5, "text": "Hello"},
                {"start": 2.5, "end": 5.0, "text": "world"}
            ],
            "language": "en"
        }
        save_transcript(result, output_path, "vtt")

        assert output_path.exists()
        content = output_path.read_text()
        assert "WEBVTT" in content
        assert "00:00:00.000 --> 00:00:02.500" in content
        assert "Hello" in content
    finally:
        output_path.unlink(missing_ok=True)


def test_add_speaker_labels():
    """Test speaker label addition"""
    from pathlib import Path
    result = {"text": "Hello world", "segments": [], "language": "en"}
    config = {}

    # Currently just returns the result as-is (pyannote not installed)
    output = add_speaker_labels(result, Path("/fake/audio.wav"), config)
    assert output == result
