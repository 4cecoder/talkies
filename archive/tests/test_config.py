"""
Tests for configuration management
"""

import pytest
import tempfile
from pathlib import Path
from unittest.mock import patch
from whisper_cli.config import load_config, save_config, DEFAULT_CONFIG, _deep_update


def test_load_config_defaults():
    """Test configuration loading with defaults"""
    config = load_config(Path("/nonexistent/config.toml"))
    assert "whisper" in config
    assert "ai_services" in config
    assert config["whisper"]["model"] == "base"
    assert config["whisper"]["device"] == "cpu"


def test_load_config_from_file():
    """Test loading configuration from a file"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.toml', delete=False) as f:
        f.write("""
[whisper]
model = "large"
device = "cuda"

[ai_services]
openai_api_key = "test-key"
""")
        f.flush()
        config_path = Path(f.name)
    
    try:
        config = load_config(config_path)
        assert config["whisper"]["model"] == "large"
        assert config["whisper"]["device"] == "cuda"
        assert config["ai_services"]["openai_api_key"] == "test-key"
        # Should still have defaults for other fields
        assert config["whisper"]["language"] is None
    finally:
        config_path.unlink()


def test_load_config_merges_with_defaults():
    """Test that user config merges with defaults"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.toml', delete=False) as f:
        f.write("""
[whisper]
model = "small"
device = "cpu"
""")
        f.flush()
        config_path = Path(f.name)
    
    try:
        config = load_config(config_path)
        # User value should override
        assert config["whisper"]["model"] == "small"
        # User specified device should be used
        assert config["whisper"]["device"] == "cpu"
        assert "ai_services" in config
        assert "output" in config
    finally:
        config_path.unlink()


def test_save_config():
    """Test saving configuration to file"""
    with tempfile.TemporaryDirectory() as tmpdir:
        config_path = Path(tmpdir) / "test_config.toml"
        test_config = {
            "whisper": {"model": "medium", "device": "cpu"},
            "ai_services": {"openai_api_key": "test-key"}
        }
        
        save_config(test_config, config_path)
        
        assert config_path.exists()
        # Verify it can be loaded back
        loaded = load_config(config_path)
        assert loaded["whisper"]["model"] == "medium"
        assert loaded["ai_services"]["openai_api_key"] == "test-key"


def test_deep_update():
    """Test deep update functionality"""
    base = {
        "whisper": {"model": "base", "device": "cpu"},
        "ai_services": {"openai_api_key": None}
    }
    update = {
        "whisper": {"model": "large"},
        "ai_services": {"openai_api_key": "new-key"}
    }
    
    _deep_update(base, update)
    
    assert base["whisper"]["model"] == "large"
    assert base["whisper"]["device"] == "cpu"  # Should preserve
    assert base["ai_services"]["openai_api_key"] == "new-key"


def test_deep_update_nested():
    """Test deep update with nested dictionaries"""
    base = {
        "section1": {
            "subsection": {"key1": "value1", "key2": "value2"}
        }
    }
    update = {
        "section1": {
            "subsection": {"key1": "new_value1"}
        }
    }
    
    _deep_update(base, update)
    
    assert base["section1"]["subsection"]["key1"] == "new_value1"
    assert base["section1"]["subsection"]["key2"] == "value2"  # Should preserve


def test_config_with_system_recommendations():
    """Test that config uses system recommendations when no file exists"""
    config = load_config(Path("/nonexistent/config.toml"))
    # Should have system-optimized defaults merged in
    assert "whisper" in config
    assert "device" in config["whisper"]

