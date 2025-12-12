"""
Core transcription functionality using Faster Whisper.
"""

from pathlib import Path
from typing import Dict, Any, Optional, List
import json
import logging

from rich.console import Console

logger = logging.getLogger(__name__)
console = Console()


class TranscriptionError(Exception):
    """Raised when transcription fails."""
    pass


class ModelNotReadyError(TranscriptionError):
    """Raised when model is not downloaded or ready."""
    pass


def transcribe_file(
    audio_path: Path,
    model: str = "base",
    language: Optional[str] = None,
    config: Optional[Dict[str, Any]] = None,
    translate: Optional[str] = None,
    speakers: bool = False,
    auto_download: bool = True,
) -> Dict[str, Any]:
    """Transcribe an audio file using Faster Whisper.

    Args:
        audio_path: Path to the audio file.
        model: Whisper model name (tiny, base, small, medium, large-v2, large-v3).
        language: Language code for transcription. Auto-detected if not specified.
        config: Configuration dictionary.
        translate: Target language code for translation. None for no translation.
        speakers: Enable speaker diarization (requires additional setup).
        auto_download: Automatically download model if not present.

    Returns:
        Dictionary with 'text', 'segments', and 'language' keys.

    Raises:
        TranscriptionError: If transcription fails.
        ModelNotReadyError: If model is downloading or not available.
    """
    from faster_whisper import WhisperModel

    if config is None:
        config = {}

    # Handle model download status
    if auto_download:
        _ensure_model_ready(model, config)

    # Get device configuration
    whisper_config = config.get('whisper', {})
    device = whisper_config.get('device', 'cpu')
    compute_type = whisper_config.get('compute_type', 'int8')

    logger.info(f"Loading model '{model}' on {device} with {compute_type}")

    try:
        model_instance = WhisperModel(
            model,
            device=device,
            compute_type=compute_type
        )
    except Exception as e:
        raise TranscriptionError(f"Failed to load model '{model}': {e}") from e

    # Transcribe
    task = "translate" if translate else "transcribe"
    logger.info(f"Transcribing {audio_path} (task={task}, language={language or 'auto'})")

    try:
        segments, info = model_instance.transcribe(
            str(audio_path),
            language=language,
            task=task,
            beam_size=5,
            vad_filter=True,
        )

        # Build result
        result = {
            "text": "",
            "segments": [],
            "language": info.language,
            "duration": info.duration,
        }

        for segment in segments:
            result["text"] += segment.text
            result["segments"].append({
                "start": segment.start,
                "end": segment.end,
                "text": segment.text.strip(),
            })

    except Exception as e:
        raise TranscriptionError(f"Transcription failed: {e}") from e

    # Add speaker recognition if enabled
    if speakers:
        result = add_speaker_labels(result, audio_path, config)

    return result


def _ensure_model_ready(model: str, config: Dict[str, Any]) -> None:
    """Ensure model is downloaded and ready.

    Checks download status and waits if necessary.
    """
    try:
        from .model_downloader import ModelDownloadManager, DownloadStatus
    except ImportError:
        # Model downloader not available, let faster-whisper handle it
        return

    manager = ModelDownloadManager()
    task = manager.get_status(model)

    if not task:
        # Model not in download queue - faster-whisper will handle download
        logger.debug(f"Model '{model}' not in download queue, will be auto-downloaded")
        return

    if task.status in [DownloadStatus.COMPLETED, DownloadStatus.VERIFIED]:
        return

    if task.status == DownloadStatus.DOWNLOADING:
        console.print(f"[yellow]Model '{model}' is downloading ({task.progress:.1f}%)... waiting[/yellow]")
        success = manager.wait_for_download(model, timeout=600)
        if not success:
            raise ModelNotReadyError(f"Model '{model}' download did not complete in time")

    elif task.status == DownloadStatus.PAUSED:
        console.print(f"[yellow]Resuming download of '{model}'...[/yellow]")
        manager.resume_download(model)
        success = manager.wait_for_download(model, timeout=600)
        if not success:
            raise ModelNotReadyError(f"Model '{model}' download did not complete")

    elif task.status == DownloadStatus.FAILED:
        raise ModelNotReadyError(f"Model '{model}' download failed: {task.error_message}")


def add_speaker_labels(
    result: Dict[str, Any],
    audio_path: Path,
    config: Dict[str, Any]
) -> Dict[str, Any]:
    """Add speaker diarization labels to transcription result.

    Currently a placeholder - full implementation would integrate with:
    - pyannote.audio for speaker diarization
    - ElevenLabs or Deepgram for speaker identification

    Args:
        result: Transcription result dictionary.
        audio_path: Path to the audio file.
        config: Configuration dictionary.

    Returns:
        Result dictionary with speaker labels added to segments.
    """
    # Check if pyannote is available
    try:
        from pyannote.audio import Pipeline
        has_pyannote = True
    except ImportError:
        has_pyannote = False

    if not has_pyannote:
        logger.warning("Speaker diarization requires pyannote.audio: uv add pyannote.audio")
        return result

    # TODO: Implement full speaker diarization
    # For now, return result unchanged
    logger.info("Speaker diarization not yet fully implemented")
    return result


def save_transcript(
    result: Dict[str, Any],
    output_path: Path,
    format: str = "txt"
) -> Path:
    """Save transcription result to file in specified format.

    Args:
        result: Transcription result dictionary.
        output_path: Path to save the output file.
        format: Output format ('txt', 'srt', 'vtt', 'json').

    Returns:
        Path to the saved file.

    Raises:
        ValueError: If format is not supported.
    """
    format = format.lower()

    if format == "txt":
        _save_txt(result, output_path)
    elif format == "srt":
        _save_srt(result, output_path)
    elif format == "vtt":
        _save_vtt(result, output_path)
    elif format == "json":
        _save_json(result, output_path)
    else:
        raise ValueError(f"Unsupported format: {format}. Use 'txt', 'srt', 'vtt', or 'json'.")

    return output_path


def _save_txt(result: Dict[str, Any], output_path: Path) -> None:
    """Save as plain text."""
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(result["text"])


def _save_json(result: Dict[str, Any], output_path: Path) -> None:
    """Save as JSON."""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)


def _save_srt(result: Dict[str, Any], output_path: Path) -> None:
    """Save as SRT (SubRip) subtitle format.

    Format:
    1
    00:00:00,000 --> 00:00:02,500
    First subtitle text

    2
    00:00:02,500 --> 00:00:05,000
    Second subtitle text
    """
    segments = result.get("segments", [])

    with open(output_path, 'w', encoding='utf-8') as f:
        for i, segment in enumerate(segments, start=1):
            start = _format_timestamp_srt(segment["start"])
            end = _format_timestamp_srt(segment["end"])
            text = segment["text"].strip()

            f.write(f"{i}\n")
            f.write(f"{start} --> {end}\n")
            f.write(f"{text}\n")
            f.write("\n")


def _save_vtt(result: Dict[str, Any], output_path: Path) -> None:
    """Save as WebVTT subtitle format.

    Format:
    WEBVTT

    00:00:00.000 --> 00:00:02.500
    First subtitle text

    00:00:02.500 --> 00:00:05.000
    Second subtitle text
    """
    segments = result.get("segments", [])

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("WEBVTT\n\n")

        for segment in segments:
            start = _format_timestamp_vtt(segment["start"])
            end = _format_timestamp_vtt(segment["end"])
            text = segment["text"].strip()

            f.write(f"{start} --> {end}\n")
            f.write(f"{text}\n")
            f.write("\n")


def _format_timestamp_srt(seconds: float) -> str:
    """Format timestamp for SRT format (HH:MM:SS,mmm)."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def _format_timestamp_vtt(seconds: float) -> str:
    """Format timestamp for VTT format (HH:MM:SS.mmm)."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"
