"""
YouTube transcription functionality
"""

from pathlib import Path
from typing import Dict, Any, Optional
from pytube import YouTube
from .transcription import transcribe_file
import tempfile
import os


def transcribe_youtube(
    url: str, config: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """Download and transcribe a YouTube video"""
    if config is None:
        config = {}

    # Download audio
    yt = YouTube(url)
    audio_stream = yt.streams.filter(only_audio=True).first()

    with tempfile.TemporaryDirectory() as temp_dir:
        audio_path = Path(temp_dir) / "audio.mp4"
        audio_stream.download(output_path=temp_dir, filename="audio.mp4")

        # Transcribe
        result = transcribe_file(audio_path, config=config)

    return result
