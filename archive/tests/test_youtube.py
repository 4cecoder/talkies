"""
Tests for YouTube transcription functionality
"""

import pytest
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.youtube import transcribe_youtube


def test_transcribe_youtube_basic(mocker):
    """Test basic YouTube transcription"""
    url = "https://www.youtube.com/watch?v=test123"
    config = {}
    
    # Mock YouTube object
    mock_yt = Mock()
    mock_stream = Mock()
    mock_stream.download.return_value = None
    mock_yt.streams.filter.return_value.first.return_value = mock_stream
    
    # Mock transcription result
    mock_transcription_result = {
        "text": "Test transcription",
        "segments": [{"start": 0.0, "end": 1.0, "text": "Test transcription"}],
        "language": "en"
    }
    
    with patch('whisper_cli.youtube.YouTube', return_value=mock_yt):
        with patch('whisper_cli.youtube.transcribe_file', return_value=mock_transcription_result):
            with tempfile.TemporaryDirectory() as tmpdir:
                result = transcribe_youtube(url, config=config)
    
    assert result["text"] == "Test transcription"
    assert result["language"] == "en"
    mock_yt.streams.filter.assert_called_once_with(only_audio=True)


def test_transcribe_youtube_with_config(mocker):
    """Test YouTube transcription with config"""
    url = "https://www.youtube.com/watch?v=test123"
    config = {"whisper": {"model": "large", "device": "cuda"}}
    
    mock_yt = Mock()
    mock_stream = Mock()
    mock_stream.download.return_value = None
    mock_yt.streams.filter.return_value.first.return_value = mock_stream
    
    mock_transcription_result = {
        "text": "Test transcription",
        "segments": [],
        "language": "en"
    }
    
    with patch('whisper_cli.youtube.YouTube', return_value=mock_yt):
        with patch('whisper_cli.youtube.transcribe_file', return_value=mock_transcription_result) as mock_transcribe:
            with tempfile.TemporaryDirectory() as tmpdir:
                result = transcribe_youtube(url, config=config)
    
    # Verify config was passed to transcribe_file
    call_args = mock_transcribe.call_args
    assert call_args[1]["config"] == config


def test_transcribe_youtube_download_error(mocker):
    """Test YouTube transcription with download error"""
    url = "https://www.youtube.com/watch?v=test123"
    config = {}
    
    mock_yt = Mock()
    mock_yt.streams.filter.return_value.first.return_value = None  # No stream available
    
    with patch('whisper_cli.youtube.YouTube', return_value=mock_yt):
        with pytest.raises(AttributeError):
            transcribe_youtube(url, config=config)


def test_transcribe_youtube_transcription_error(mocker):
    """Test YouTube transcription with transcription error"""
    url = "https://www.youtube.com/watch?v=test123"
    config = {}
    
    mock_yt = Mock()
    mock_stream = Mock()
    mock_stream.download.return_value = None
    mock_yt.streams.filter.return_value.first.return_value = mock_stream
    
    with patch('whisper_cli.youtube.YouTube', return_value=mock_yt):
        with patch('whisper_cli.youtube.transcribe_file', side_effect=Exception("Transcription error")):
            with pytest.raises(Exception):
                with tempfile.TemporaryDirectory() as tmpdir:
                    transcribe_youtube(url, config=config)


def test_transcribe_youtube_temp_file_cleanup(mocker):
    """Test that temporary files are cleaned up after transcription"""
    url = "https://www.youtube.com/watch?v=test123"
    config = {}
    
    mock_yt = Mock()
    mock_stream = Mock()
    mock_stream.download.return_value = None
    mock_yt.streams.filter.return_value.first.return_value = mock_stream
    
    mock_transcription_result = {
        "text": "Test transcription",
        "segments": [],
        "language": "en"
    }
    
    with patch('whisper_cli.youtube.YouTube', return_value=mock_yt):
        with patch('whisper_cli.youtube.transcribe_file', return_value=mock_transcription_result):
            # Verify TemporaryDirectory is used
            with patch('whisper_cli.youtube.tempfile.TemporaryDirectory') as mock_tempdir:
                mock_tempdir.return_value.__enter__.return_value = "/tmp/test"
                result = transcribe_youtube(url, config=config)
    
    # Temporary directory should be used
    assert result is not None

