"""
Tests for Whisper CLI
"""

import pytest
from pathlib import Path
from whisper_cli.config import load_config, DEFAULT_CONFIG


def test_load_config():
    """Test configuration loading"""
    # Test with non-existent config path (should use defaults)
    config = load_config(Path("/nonexistent/config.toml"))
    assert "whisper" in config
    assert "ai_services" in config
    assert config["whisper"]["model"] == "base"


def test_transcription_placeholder():
    """Placeholder for transcription tests"""
    # This would require actual audio files and mocking
    pass


if __name__ == "__main__":
    pytest.main([__file__])
