"""
Tests for CLI commands
"""

import pytest
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from click.testing import CliRunner
from whisper_cli.cli import cli


@pytest.fixture
def runner():
    """Create a CLI runner for testing"""
    return CliRunner()


@pytest.fixture
def mock_config():
    """Create a mock config"""
    return {
        "whisper": {"model": "base", "device": "cpu"},
        "ai_services": {},
        "output": {"format": "txt"},
        "recording": {"sample_rate": 16000, "channels": 1}
    }


def test_cli_help(runner):
    """Test CLI help command"""
    result = runner.invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "Whisper CLI" in result.output


def test_cli_transcribe_command(runner, mock_config):
    """Test transcribe command"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_file = Path(f.name)
        f.write(b"fake audio data")
    
    try:
        mock_result = {
            "text": "Test transcription",
            "segments": [],
            "language": "en"
        }
        
        with patch('whisper_cli.cli.load_config', return_value=mock_config):
            with patch('whisper_cli.cli.transcribe_file', return_value=mock_result):
                with patch('whisper_cli.cli.save_transcript') as mock_save:
                    result = runner.invoke(cli, ["transcribe", str(audio_file)])
        
        assert result.exit_code == 0
        mock_save.assert_called_once()
    finally:
        audio_file.unlink(missing_ok=True)


def test_cli_transcribe_with_options(runner, mock_config):
    """Test transcribe command with various options"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_file = Path(f.name)
        f.write(b"fake audio data")
    
    try:
        mock_result = {
            "text": "Test transcription",
            "segments": [],
            "language": "en"
        }
        
        with patch('whisper_cli.cli.load_config', return_value=mock_config):
            with patch('whisper_cli.cli.transcribe_file', return_value=mock_result) as mock_transcribe:
                with patch('whisper_cli.cli.save_transcript'):
                    result = runner.invoke(cli, [
                        "transcribe",
                        str(audio_file),
                        "--model", "large",
                        "--language", "en",
                        "--format", "json",
                        "--improve"
                    ])
        
        assert result.exit_code == 0
        # Verify options were passed
        call_args = mock_transcribe.call_args
        assert call_args[1]["model"] == "large"
        assert call_args[1]["language"] == "en"
    finally:
        audio_file.unlink(missing_ok=True)


def test_cli_transcribe_error_handling(runner, mock_config):
    """Test transcribe command error handling"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        audio_file = Path(f.name)
        f.write(b"fake audio data")
    
    try:
        with patch('whisper_cli.cli.load_config', return_value=mock_config):
            with patch('whisper_cli.cli.transcribe_file', side_effect=Exception("Transcription error")):
                result = runner.invoke(cli, ["transcribe", str(audio_file)])
        
        assert result.exit_code != 0
    finally:
        audio_file.unlink(missing_ok=True)


def test_cli_batch_command(runner, mock_config):
    """Test batch command"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        (input_dir / "test.wav").write_bytes(b"fake audio data")
        
        with patch('whisper_cli.cli.load_config', return_value=mock_config):
            with patch('whisper_cli.cli.batch_transcribe') as mock_batch:
                result = runner.invoke(cli, ["batch", str(input_dir)])
        
        assert result.exit_code == 0
        mock_batch.assert_called_once()


def test_cli_batch_with_options(runner, mock_config):
    """Test batch command with options"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_dir = Path(tmpdir)
        output_dir = Path(tmpdir) / "output"
        
        with patch('whisper_cli.cli.load_config', return_value=mock_config):
            with patch('whisper_cli.cli.batch_transcribe') as mock_batch:
                result = runner.invoke(cli, [
                    "batch",
                    str(input_dir),
                    "--output-dir", str(output_dir),
                    "--recursive"
                ])
        
        assert result.exit_code == 0
        call_args = mock_batch.call_args
        assert call_args[1]["recursive"] is True


def test_cli_watch_command(runner, mock_config):
    """Test watch command"""
    with tempfile.TemporaryDirectory() as tmpdir:
        folder = Path(tmpdir)
        
        with patch('whisper_cli.cli.load_config', return_value=mock_config):
            with patch('whisper_cli.cli.watch_folder') as mock_watch:
                # watch_folder uses time.sleep internally, so we mock it there
                with patch('whisper_cli.watch.time.sleep', side_effect=KeyboardInterrupt):
                    result = runner.invoke(cli, ["watch", str(folder)])
        
        assert result.exit_code == 0
        mock_watch.assert_called_once()


def test_cli_youtube_command(runner, mock_config):
    """Test YouTube command"""
    url = "https://www.youtube.com/watch?v=test123"
    
    mock_result = {
        "text": "Test transcription",
        "segments": [],
        "language": "en"
    }
    
    with patch('whisper_cli.cli.load_config', return_value=mock_config):
        with patch('whisper_cli.cli.transcribe_youtube', return_value=mock_result):
            with patch('whisper_cli.cli.save_transcript') as mock_save:
                result = runner.invoke(cli, ["youtube", url])
    
    assert result.exit_code == 0
    mock_save.assert_called_once()


def test_cli_youtube_with_options(runner, mock_config):
    """Test YouTube command with options"""
    url = "https://www.youtube.com/watch?v=test123"
    
    mock_result = {
        "text": "Test transcription",
        "segments": [],
        "language": "en"
    }
    
    with patch('whisper_cli.cli.load_config', return_value=mock_config):
        with patch('whisper_cli.cli.transcribe_youtube', return_value=mock_result):
            with patch('whisper_cli.cli.save_transcript'):
                result = runner.invoke(cli, [
                    "youtube",
                    url,
                    "--format", "srt",
                    "--output", "output.srt"
                ])
    
    assert result.exit_code == 0


def test_cli_system_command(runner):
    """Test system command"""
    with patch('whisper_cli.cli.print_system_info') as mock_print:
        result = runner.invoke(cli, ["system"])
    
    assert result.exit_code == 0
    mock_print.assert_called_once()


def test_cli_system_recommend_command(runner):
    """Test system recommend command"""
    mock_recommended = {
        "whisper": {"device": "cuda"},
        "recording": {"backend": "sounddevice"}
    }
    
    with patch('whisper_cli.cli.get_recommended_config', return_value=mock_recommended):
        with patch('whisper_cli.cli.console.print') as mock_console:
            result = runner.invoke(cli, ["system", "--recommend"])
    
    assert result.exit_code == 0
    assert mock_console.called


def test_cli_config_loading(runner):
    """Test that config is loaded correctly"""
    with tempfile.NamedTemporaryFile(suffix='.toml', delete=False) as f:
        config_path = Path(f.name)
        f.write(b"[whisper]\nmodel = 'large'\n")
    
    try:
        with patch('whisper_cli.cli.load_config') as mock_load:
            mock_load.return_value = {"whisper": {"model": "large"}}
            result = runner.invoke(cli, ["--config", str(config_path), "system"])
        
        # Verify config path was expanded and passed
        mock_load.assert_called_once()
    finally:
        config_path.unlink(missing_ok=True)

