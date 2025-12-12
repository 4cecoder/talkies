"""
Audio recording functionality with cross-platform support.
Supports both PyAudio and SoundDevice backends.
"""

from pathlib import Path
from typing import Dict, Any, Optional, List
import wave
import logging

from rich.console import Console

logger = logging.getLogger(__name__)
console = Console()


class RecordingError(Exception):
    """Raised when audio recording fails."""
    pass


class NoAudioBackendError(RecordingError):
    """Raised when no audio backend is available."""
    pass


class DeviceNotFoundError(RecordingError):
    """Raised when specified audio device is not found."""
    pass


def list_audio_devices() -> List[Dict[str, Any]]:
    """List available audio input devices.

    Returns:
        List of device info dictionaries with 'index', 'name', and 'channels' keys.
    """
    devices = []

    # Try sounddevice first
    try:
        import sounddevice as sd
        for i, dev in enumerate(sd.query_devices()):
            if dev.get('max_input_channels', 0) > 0:
                devices.append({
                    'index': i,
                    'name': dev['name'],
                    'channels': dev['max_input_channels'],
                    'backend': 'sounddevice'
                })
        return devices
    except ImportError:
        pass

    # Fall back to PyAudio
    try:
        import pyaudio
        audio = pyaudio.PyAudio()
        try:
            for i in range(audio.get_device_count()):
                dev = audio.get_device_info_by_index(i)
                if dev.get('maxInputChannels', 0) > 0:
                    devices.append({
                        'index': i,
                        'name': dev['name'],
                        'channels': dev['maxInputChannels'],
                        'backend': 'pyaudio'
                    })
        finally:
            audio.terminate()
        return devices
    except ImportError:
        pass

    return devices


def record_audio(
    output_path: Path,
    duration: Optional[int] = None,
    device: Optional[str] = None,
    config: Optional[Dict[str, Any]] = None
) -> Path:
    """Record audio from microphone.

    Args:
        output_path: Path to save the recorded audio (WAV format).
        duration: Recording duration in seconds. If None, records until Ctrl+C.
        device: Device name to use (partial match). If None, uses default device.
        config: Configuration dictionary with optional 'recording' section.

    Returns:
        Path to the saved audio file.

    Raises:
        NoAudioBackendError: If neither sounddevice nor pyaudio is available.
        DeviceNotFoundError: If specified device is not found.
        RecordingError: If recording fails for any other reason.
    """
    if config is None:
        config = {}

    recording_config = config.get('recording', {})
    sample_rate = recording_config.get('sample_rate', 16000)
    channels = recording_config.get('channels', 1)

    # Detect available backend
    backend = _detect_audio_backend()

    if backend == 'sounddevice':
        return _record_with_sounddevice(output_path, duration, device, sample_rate, channels)
    elif backend == 'pyaudio':
        return _record_with_pyaudio(output_path, duration, device, sample_rate, channels)
    else:
        raise NoAudioBackendError(
            "No audio recording backend available. Install 'sounddevice' or 'pyaudio':\n"
            "  uv add sounddevice\n"
            "  uv add pyaudio"
        )


def _detect_audio_backend() -> Optional[str]:
    """Detect the best available audio backend.

    Returns:
        'sounddevice', 'pyaudio', or None if no backend is available.
    """
    # Prefer sounddevice (better cross-platform support, especially on macOS)
    try:
        import sounddevice as sd
        # Verify it can query devices
        sd.query_devices()
        return 'sounddevice'
    except (ImportError, Exception) as e:
        logger.debug(f"sounddevice not available: {e}")

    try:
        import pyaudio
        audio = pyaudio.PyAudio()
        audio.terminate()
        return 'pyaudio'
    except (ImportError, Exception) as e:
        logger.debug(f"pyaudio not available: {e}")

    return None


def _find_device_index(device_name: str, backend: str) -> int:
    """Find device index by partial name match.

    Args:
        device_name: Partial device name to search for (case-insensitive).
        backend: Either 'sounddevice' or 'pyaudio'.

    Returns:
        Device index.

    Raises:
        DeviceNotFoundError: If device is not found.
    """
    device_lower = device_name.lower()

    if backend == 'sounddevice':
        import sounddevice as sd
        for i, dev in enumerate(sd.query_devices()):
            if device_lower in dev['name'].lower() and dev.get('max_input_channels', 0) > 0:
                return i
    else:
        import pyaudio
        audio = pyaudio.PyAudio()
        try:
            for i in range(audio.get_device_count()):
                dev = audio.get_device_info_by_index(i)
                if device_lower in dev['name'].lower() and dev.get('maxInputChannels', 0) > 0:
                    return i
        finally:
            audio.terminate()

    raise DeviceNotFoundError(f"Audio device '{device_name}' not found. Use list_audio_devices() to see available devices.")


def _record_with_pyaudio(
    output_path: Path,
    duration: Optional[int],
    device: Optional[str],
    sample_rate: int,
    channels: int
) -> Path:
    """Record using PyAudio backend."""
    import pyaudio

    chunk = 1024
    audio = pyaudio.PyAudio()

    try:
        # Find device if specified
        device_index = None
        if device:
            device_index = _find_device_index(device, 'pyaudio')
            logger.info(f"Using device index {device_index} for '{device}'")

        stream = audio.open(
            format=pyaudio.paInt16,
            channels=channels,
            rate=sample_rate,
            input=True,
            input_device_index=device_index,
            frames_per_buffer=chunk
        )

        if duration:
            console.print(f"[yellow]Recording for {duration} seconds...[/yellow]")
        else:
            console.print("[yellow]Recording... Press Ctrl+C to stop[/yellow]")

        frames = []

        try:
            if duration:
                num_chunks = int(sample_rate / chunk * duration)
                for i in range(num_chunks):
                    data = stream.read(chunk, exception_on_overflow=False)
                    frames.append(data)
            else:
                while True:
                    data = stream.read(chunk, exception_on_overflow=False)
                    frames.append(data)
        except KeyboardInterrupt:
            pass

        console.print("[green]Recording finished[/green]")

        stream.stop_stream()
        stream.close()

        # Save to WAV file
        _save_wav_pyaudio(output_path, frames, channels, sample_rate, audio)

    finally:
        audio.terminate()

    console.print(f"[green]Audio saved to {output_path}[/green]")
    return output_path


def _save_wav_pyaudio(output_path: Path, frames: list, channels: int, sample_rate: int, audio) -> None:
    """Save recorded frames to WAV file using PyAudio sample width."""
    import pyaudio

    with wave.open(str(output_path), 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(audio.get_sample_size(pyaudio.paInt16))
        wf.setframerate(sample_rate)
        wf.writeframes(b''.join(frames))


def _record_with_sounddevice(
    output_path: Path,
    duration: Optional[int],
    device: Optional[str],
    sample_rate: int,
    channels: int
) -> Path:
    """Record using SoundDevice backend (preferred for cross-platform support)."""
    import sounddevice as sd
    import numpy as np

    # Find device if specified
    device_index = None
    if device:
        device_index = _find_device_index(device, 'sounddevice')
        logger.info(f"Using device index {device_index} for '{device}'")

    if duration:
        console.print(f"[yellow]Recording for {duration} seconds...[/yellow]")
    else:
        console.print("[yellow]Recording... Press Ctrl+C to stop[/yellow]")

    try:
        if duration:
            # Fixed duration recording
            recording = sd.rec(
                int(duration * sample_rate),
                samplerate=sample_rate,
                channels=channels,
                device=device_index,
                dtype=np.int16
            )
            sd.wait()
        else:
            # Continuous recording until Ctrl+C
            chunk_size = 1024
            chunks = []

            with sd.InputStream(
                samplerate=sample_rate,
                channels=channels,
                device=device_index,
                dtype=np.int16
            ) as stream:
                try:
                    while True:
                        data, overflowed = stream.read(chunk_size)
                        chunks.append(data.copy())
                        if overflowed:
                            logger.warning("Audio buffer overflowed")
                except KeyboardInterrupt:
                    pass

            recording = np.concatenate(chunks) if chunks else np.array([], dtype=np.int16)

    except KeyboardInterrupt:
        if duration:
            sd.stop()
            # Get whatever was recorded
            recording = sd.rec(0, samplerate=sample_rate, channels=channels, dtype=np.int16)

    console.print("[green]Recording finished[/green]")

    # Save to WAV file
    _save_wav_numpy(output_path, recording, channels, sample_rate)

    console.print(f"[green]Audio saved to {output_path}[/green]")
    return output_path


def _save_wav_numpy(output_path: Path, recording, channels: int, sample_rate: int) -> None:
    """Save numpy array recording to WAV file."""
    with wave.open(str(output_path), 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit = 2 bytes
        wf.setframerate(sample_rate)
        wf.writeframes(recording.tobytes())
