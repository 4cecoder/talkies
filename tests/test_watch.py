"""
Tests for watch folder functionality
"""

import pytest
import tempfile
import time
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.watch import watch_folder, AudioFileHandler


def test_audio_file_handler_matches_pattern():
    """Test that AudioFileHandler correctly matches audio file patterns"""
    handler = AudioFileHandler(
        output_dir=Path("/tmp"),
        patterns={"*.mp3", "*.wav", "*.flac", "*.m4a"},
        format="txt",
        model="base",
        language=None,
        improve=False,
        config={}
    )

    # Test with just filename (not full path)
    assert handler._matches_pattern("file.wav") is True
    assert handler._matches_pattern("file.mp3") is True
    assert handler._matches_pattern("file.flac") is True
    assert handler._matches_pattern("file.m4a") is True
    assert handler._matches_pattern("file.txt") is False


def test_audio_file_handler_matches_pattern_empty():
    """Test that empty patterns matches all files"""
    handler = AudioFileHandler(
        output_dir=Path("/tmp"),
        patterns=set(),  # Empty set = match all
        format="txt",
        model="base",
        language=None,
        improve=False,
        config={}
    )

    assert handler._matches_pattern("anything.wav") is True
    assert handler._matches_pattern("anything.mp3") is True


def test_audio_file_handler_on_created(mocker):
    """Test AudioFileHandler on_created event"""
    with tempfile.TemporaryDirectory() as tmpdir:
        output_dir = Path(tmpdir) / "output"
        output_dir.mkdir()

        handler = AudioFileHandler(
            output_dir=output_dir,
            patterns={"*.wav"},
            format="txt",
            model="base",
            language=None,
            improve=False,
            config={}
        )

        # Create a mock event
        mock_event = Mock()
        mock_event.is_directory = False
        mock_event.src_path = str(Path(tmpdir) / "test.wav")

        # Create the file
        Path(mock_event.src_path).write_bytes(b"fake audio data")

        with patch('whisper_cli.watch.transcribe_file') as mock_transcribe:
            with patch('whisper_cli.watch.save_transcript') as mock_save:
                with patch('whisper_cli.watch.time.sleep'):  # Skip the 1s delay
                    mock_transcribe.return_value = {
                        "text": "Test transcription",
                        "segments": [],
                        "language": "en"
                    }

                    handler.on_created(mock_event)

        mock_transcribe.assert_called_once()
        mock_save.assert_called_once()


def test_audio_file_handler_ignores_directories():
    """Test that AudioFileHandler ignores directory events"""
    handler = AudioFileHandler(
        output_dir=Path("/tmp"),
        patterns={"*.wav"},
        format="txt",
        model="base",
        language=None,
        improve=False,
        config={}
    )

    mock_event = Mock()
    mock_event.is_directory = True
    mock_event.src_path = "/path/to/directory"

    with patch('whisper_cli.watch.transcribe_file') as mock_transcribe:
        handler.on_created(mock_event)

    mock_transcribe.assert_not_called()


def test_audio_file_handler_ignores_non_audio_files():
    """Test that AudioFileHandler ignores non-audio files"""
    handler = AudioFileHandler(
        output_dir=Path("/tmp"),
        patterns={"*.wav"},
        format="txt",
        model="base",
        language=None,
        improve=False,
        config={}
    )

    mock_event = Mock()
    mock_event.is_directory = False
    mock_event.src_path = "/path/to/file.txt"

    with patch('whisper_cli.watch.transcribe_file') as mock_transcribe:
        handler.on_created(mock_event)

    mock_transcribe.assert_not_called()


def test_audio_file_handler_error_handling(mocker):
    """Test that AudioFileHandler handles transcription errors gracefully"""
    with tempfile.TemporaryDirectory() as tmpdir:
        output_dir = Path(tmpdir) / "output"
        output_dir.mkdir()

        handler = AudioFileHandler(
            output_dir=output_dir,
            patterns={"*.wav"},
            format="txt",
            model="base",
            language=None,
            improve=False,
            config={}
        )

        mock_event = Mock()
        mock_event.is_directory = False
        mock_event.src_path = str(Path(tmpdir) / "test.wav")

        Path(mock_event.src_path).write_bytes(b"fake audio data")

        with patch('whisper_cli.watch.transcribe_file', side_effect=Exception("Transcription error")):
            with patch('whisper_cli.watch.console.print') as mock_print:
                with patch('whisper_cli.watch.time.sleep'):  # Skip the 1s delay
                    handler.on_created(mock_event)

        # Should print error but not crash
        assert mock_print.called


def test_watch_folder_basic(mocker):
    """Test basic watch folder functionality"""
    with tempfile.TemporaryDirectory() as tmpdir:
        folder = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"
        config = {}

        with patch('whisper_cli.watch.Observer') as mock_observer_class:
            mock_observer = Mock()
            mock_observer_class.return_value = mock_observer

            with patch('whisper_cli.watch.time.sleep', side_effect=KeyboardInterrupt):
                watch_folder(folder, output_dir=output_dir, config=config)

        mock_observer.schedule.assert_called_once()
        mock_observer.start.assert_called_once()
        mock_observer.stop.assert_called_once()
        mock_observer.join.assert_called_once()


def test_watch_folder_default_output_dir(mocker):
    """Test watch folder with default output directory"""
    with tempfile.TemporaryDirectory() as tmpdir:
        folder = Path(tmpdir)
        config = {}

        with patch('whisper_cli.watch.Observer') as mock_observer_class:
            mock_observer = Mock()
            mock_observer_class.return_value = mock_observer

            with patch('whisper_cli.watch.time.sleep', side_effect=KeyboardInterrupt):
                watch_folder(folder, output_dir=None, config=config)

        # Should use folder as output_dir
        mock_observer.schedule.assert_called_once()
        call_args = mock_observer.schedule.call_args
        handler = call_args[0][0]
        assert handler.output_dir == folder


def test_watch_folder_with_config(mocker):
    """Test watch folder with config passed through"""
    with tempfile.TemporaryDirectory() as tmpdir:
        folder = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"
        config = {"whisper": {"model": "large"}}

        with patch('whisper_cli.watch.Observer') as mock_observer_class:
            mock_observer = Mock()
            mock_observer_class.return_value = mock_observer

            with patch('whisper_cli.watch.time.sleep', side_effect=KeyboardInterrupt):
                watch_folder(folder, output_dir=output_dir, config=config)

        # Verify config was passed to handler
        call_args = mock_observer.schedule.call_args
        handler = call_args[0][0]
        assert handler.config == config


def test_watch_folder_recursive(mocker):
    """Test watch folder with recursive watching"""
    with tempfile.TemporaryDirectory() as tmpdir:
        folder = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"
        config = {}

        with patch('whisper_cli.watch.Observer') as mock_observer_class:
            mock_observer = Mock()
            mock_observer_class.return_value = mock_observer

            with patch('whisper_cli.watch.time.sleep', side_effect=KeyboardInterrupt):
                watch_folder(folder, output_dir=output_dir, config=config)

        # Should schedule with recursive=True
        call_args = mock_observer.schedule.call_args
        assert call_args[1]["recursive"] is True
