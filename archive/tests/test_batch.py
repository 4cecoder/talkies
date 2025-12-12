"""
Tests for batch transcription functionality
"""

import pytest
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.batch import batch_transcribe, find_audio_files, BatchResult


def test_find_audio_files_basic():
    """Test finding audio files in a directory"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)

        # Create audio files
        (input_dir / "test1.wav").write_bytes(b"fake audio 1")
        (input_dir / "test2.mp3").write_bytes(b"fake audio 2")
        (input_dir / "test3.txt").write_bytes(b"not audio")

        files = find_audio_files(input_dir)

        assert len(files) == 2
        assert any(f.name == "test1.wav" for f in files)
        assert any(f.name == "test2.mp3" for f in files)


def test_find_audio_files_recursive():
    """Test finding audio files recursively"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        subdir = input_dir / "subdir"
        subdir.mkdir()

        (input_dir / "test1.wav").write_bytes(b"fake audio 1")
        (subdir / "test2.wav").write_bytes(b"fake audio 2")

        # Non-recursive
        files = find_audio_files(input_dir, recursive=False)
        assert len(files) == 1

        # Recursive
        files = find_audio_files(input_dir, recursive=True)
        assert len(files) == 2


def test_find_audio_files_with_pattern():
    """Test finding audio files with pattern filter"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)

        (input_dir / "test1.wav").write_bytes(b"fake audio 1")
        (input_dir / "test2.mp3").write_bytes(b"fake audio 2")
        (input_dir / "test3.flac").write_bytes(b"fake audio 3")

        files = find_audio_files(input_dir, pattern="*.wav")
        assert len(files) == 1
        assert files[0].name == "test1.wav"


def test_batch_transcribe_single_file(mocker):
    """Test batch transcription of a single file"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        # Create a fake audio file with proper extension
        audio_file = input_dir / "test.wav"
        audio_file.write_bytes(b"fake audio data")

        # Mock transcribe_file and save_transcript
        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, config={})

        mock_transcribe.assert_called_once()
        mock_save.assert_called_once()
        assert output_dir.exists()
        assert isinstance(result, BatchResult)
        assert result.total == 1
        assert result.successful == 1


def test_batch_transcribe_multiple_files(mocker):
    """Test batch transcription of multiple files"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        # Create multiple fake audio files
        files = [
            input_dir / "test1.wav",
            input_dir / "test2.mp3",
            input_dir / "test3.flac"
        ]
        for f in files:
            f.write_bytes(b"fake audio data")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, config={})

        # Should be called for each audio file
        assert mock_transcribe.call_count == 3
        assert mock_save.call_count == 3
        assert result.total == 3
        assert result.successful == 3


def test_batch_transcribe_recursive(mocker):
    """Test batch transcription with recursive directory traversal"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        # Create nested structure
        subdir = input_dir / "subdir"
        subdir.mkdir()
        files = [
            input_dir / "test1.wav",
            subdir / "test2.wav"
        ]
        for f in files:
            f.write_bytes(b"fake audio data")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, recursive=True, config={})

        # Should find files in both root and subdirectory
        assert mock_transcribe.call_count == 2
        assert result.total == 2


def test_batch_transcribe_non_recursive(mocker):
    """Test batch transcription without recursive traversal"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        # Create nested structure
        subdir = input_dir / "subdir"
        subdir.mkdir()
        (input_dir / "test1.wav").write_bytes(b"fake audio data 1")
        (subdir / "test2.wav").write_bytes(b"fake audio data 2")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, recursive=False, config={})

        # Should only find files in root directory
        assert mock_transcribe.call_count == 1
        assert result.total == 1


def test_batch_transcribe_custom_pattern(mocker):
    """Test batch transcription with custom file pattern"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        # Create files with different extensions
        (input_dir / "test1.wav").write_bytes(b"fake audio data 1")
        (input_dir / "test2.mp3").write_bytes(b"fake audio data 2")
        (input_dir / "test3.txt").write_bytes(b"not audio data")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, pattern="*.wav", config={})

        # Should only process .wav files
        assert mock_transcribe.call_count == 1
        assert result.total == 1


def test_batch_transcribe_error_handling(mocker):
    """Test batch transcription error handling"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        # Create audio files
        files = [
            input_dir / "test1.wav",
            input_dir / "test2.wav"
        ]
        for f in files:
            f.write_bytes(b"fake audio data")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        # Make one call fail
        call_count = [0]
        def side_effect(*args, **kwargs):
            call_count[0] += 1
            if call_count[0] == 1:
                raise Exception("Transcription error")
            return mock_result

        with patch('whisper_cli.batch.transcribe_file', side_effect=side_effect) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                # Should continue processing other files despite error
                result = batch_transcribe(input_dir, output_dir=output_dir, config={})

        # Should attempt both files
        assert mock_transcribe.call_count == 2
        # Should save the successful one
        assert mock_save.call_count == 1
        assert result.failed == 1
        assert result.successful == 1


def test_batch_transcribe_default_output_dir(mocker):
    """Test batch transcription with default output directory"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)

        # Create audio file
        audio_file = input_dir / "test.wav"
        audio_file.write_bytes(b"fake audio data")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=None, config={})

        # Should use input_dir as output_dir
        mock_transcribe.assert_called_once()
        mock_save.assert_called_once()
        # Check that output was saved to input_dir
        call_args = mock_save.call_args
        output_path = call_args[0][1]
        assert output_path.parent == input_dir


def test_batch_transcribe_with_config(mocker):
    """Test batch transcription with config passed through"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"

        audio_file = input_dir / "test.wav"
        audio_file.write_bytes(b"fake audio data")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}
        config = {"whisper": {"model": "large", "device": "cuda"}}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, config=config)

        # Verify config was passed to transcribe_file
        call_args = mock_transcribe.call_args
        assert call_args[1]["config"] == config


def test_batch_transcribe_skip_existing(mocker):
    """Test batch transcription skips existing output files"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"
        output_dir.mkdir()

        # Create audio file
        audio_file = input_dir / "test.wav"
        audio_file.write_bytes(b"fake audio data")

        # Create existing output file
        (output_dir / "test.txt").write_text("existing")

        mock_result = {"text": "Test transcription", "segments": [], "language": "en"}

        with patch('whisper_cli.batch.transcribe_file', return_value=mock_result) as mock_transcribe:
            with patch('whisper_cli.batch.save_transcript') as mock_save:
                result = batch_transcribe(input_dir, output_dir=output_dir, config={})

        # Should skip the file
        mock_transcribe.assert_not_called()
        assert result.skipped == 1
        assert result.successful == 0


def test_batch_result_dataclass():
    """Test BatchResult dataclass"""
    result = BatchResult(
        total=10,
        successful=7,
        failed=2,
        skipped=1,
        results=[{"status": "success"}]
    )

    assert result.total == 10
    assert result.successful == 7
    assert result.failed == 2
    assert result.skipped == 1
    assert len(result.results) == 1
