"""
Tests for audio recording functionality
"""

import pytest
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.record import (
    record_audio,
    _record_with_pyaudio,
    _record_with_sounddevice,
    _detect_audio_backend,
    list_audio_devices,
    NoAudioBackendError,
    DeviceNotFoundError,
)


def test_detect_audio_backend_returns_valid():
    """Test that backend detection returns a valid value"""
    result = _detect_audio_backend()
    # Result depends on what's actually installed in test environment
    assert result in ['sounddevice', 'pyaudio', None]


def test_record_audio_no_backend():
    """Test recording when no audio backend is available"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        output_path = Path(f.name)

    try:
        config = {
            "recording": {
                "sample_rate": 16000,
                "channels": 1
            }
        }

        with patch('whisper_cli.record._detect_audio_backend', return_value=None):
            with pytest.raises(NoAudioBackendError):
                record_audio(output_path, duration=1, config=config)
    finally:
        output_path.unlink(missing_ok=True)


def test_record_audio_with_sounddevice():
    """Test recording routes to sounddevice when available"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        output_path = Path(f.name)

    try:
        config = {
            "recording": {
                "sample_rate": 16000,
                "channels": 1
            }
        }

        with patch('whisper_cli.record._detect_audio_backend', return_value='sounddevice'):
            with patch('whisper_cli.record._record_with_sounddevice', return_value=output_path) as mock_record:
                result = record_audio(output_path, duration=1, config=config)

        mock_record.assert_called_once()
        assert result == output_path
    finally:
        output_path.unlink(missing_ok=True)


def test_record_audio_with_pyaudio():
    """Test recording routes to pyaudio when sounddevice unavailable"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        output_path = Path(f.name)

    try:
        config = {
            "recording": {
                "sample_rate": 16000,
                "channels": 1
            }
        }

        with patch('whisper_cli.record._detect_audio_backend', return_value='pyaudio'):
            with patch('whisper_cli.record._record_with_pyaudio', return_value=output_path) as mock_record:
                result = record_audio(output_path, duration=1, config=config)

        mock_record.assert_called_once()
        assert result == output_path
    finally:
        output_path.unlink(missing_ok=True)


def test_record_with_pyaudio_basic():
    """Test PyAudio recording"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        output_path = Path(f.name)

    try:
        # Mock PyAudio
        mock_pyaudio_module = Mock()
        mock_pyaudio_module.paInt16 = 8  # Some constant

        mock_audio = Mock()
        mock_audio.get_device_count.return_value = 1
        mock_audio.get_device_info_by_index.return_value = {"name": "default"}
        mock_audio.get_sample_size.return_value = 2
        mock_pyaudio_module.PyAudio.return_value = mock_audio

        mock_stream = Mock()
        mock_stream.read.return_value = b"fake audio data"
        mock_audio.open.return_value = mock_stream

        with patch.dict('sys.modules', {'pyaudio': mock_pyaudio_module}):
            with patch('whisper_cli.record.wave.open') as mock_wave:
                _record_with_pyaudio(output_path, duration=1, device=None, sample_rate=16000, channels=1)

        mock_audio.open.assert_called_once()
        mock_stream.stop_stream.assert_called_once()
        mock_stream.close.assert_called_once()
        mock_audio.terminate.assert_called_once()
    finally:
        output_path.unlink(missing_ok=True)


def test_record_audio_config_defaults():
    """Test recording with default config values"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        output_path = Path(f.name)

    try:
        config = {}  # Empty config should use defaults

        with patch('whisper_cli.record._detect_audio_backend', return_value='sounddevice'):
            with patch('whisper_cli.record._record_with_sounddevice', return_value=output_path) as mock_record:
                record_audio(output_path, duration=1, config=config)

        # Check that defaults are used (16000 and 1)
        call_args = mock_record.call_args
        # _record_with_sounddevice(output_path, duration, device, sample_rate, channels)
        assert call_args[0][3] == 16000  # sample_rate is 4th positional arg (index 3)
        assert call_args[0][4] == 1  # channels is 5th positional arg (index 4)
    finally:
        output_path.unlink(missing_ok=True)


def test_list_audio_devices():
    """Test listing audio devices returns a list"""
    devices = list_audio_devices()
    # Just verify it returns a list - actual devices depend on environment
    assert isinstance(devices, list)
