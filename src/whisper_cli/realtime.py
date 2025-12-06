"""
Real-time streaming transcription with blazing-fast VTT generation.
Optimized for Apple Silicon (M4 Pro) with Metal acceleration.
"""

from pathlib import Path
from typing import Dict, Any, Optional, Callable, List
import queue
import threading
import time
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta

import numpy as np
import sounddevice as sd

from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.text import Text

logger = logging.getLogger(__name__)
console = Console()


@dataclass
class VTTSegment:
    """Real-time VTT segment with timing."""
    start: float
    end: float
    text: str
    confidence: float = 1.0

    def to_vtt(self) -> str:
        """Convert to VTT format."""
        start_time = self._format_timestamp(self.start)
        end_time = self._format_timestamp(self.end)
        return f"{start_time} --> {end_time}\n{self.text}\n\n"

    @staticmethod
    def _format_timestamp(seconds: float) -> str:
        """Format timestamp for VTT (HH:MM:SS.mmm)."""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


class RealtimeVTTStream:
    """Real-time VTT streaming with sub-second latency."""

    def __init__(
        self,
        model: str = "base",
        language: Optional[str] = None,
        sample_rate: int = 16000,
        chunk_duration: float = 1.0,  # Process every 1 second
        use_mlx: bool = True,  # Use MLX for M4 acceleration
        vad_enabled: bool = True,
        config: Optional[Dict[str, Any]] = None
    ):
        """
        Initialize real-time VTT streaming.

        Args:
            model: Whisper model size (tiny, base, small, medium, large)
            language: Language code (auto-detect if None)
            sample_rate: Audio sample rate (16kHz optimal for Whisper)
            chunk_duration: How often to process audio chunks (seconds)
            use_mlx: Use MLX Whisper for M4 acceleration (much faster!)
            vad_enabled: Use Voice Activity Detection to skip silence
            config: Configuration dictionary
        """
        self.model = model
        self.language = language
        self.sample_rate = sample_rate
        self.chunk_duration = chunk_duration
        self.chunk_size = int(sample_rate * chunk_duration)
        self.use_mlx = use_mlx
        self.vad_enabled = vad_enabled
        self.config = config or {}

        # Audio buffer and processing
        self.audio_queue = queue.Queue()
        self.vtt_segments: List[VTTSegment] = []
        self.is_recording = False
        self.stream = None
        self.start_time = None

        # Callbacks
        self.on_segment_callback: Optional[Callable[[VTTSegment], None]] = None

        # Threading
        self.processor_thread = None
        self.stop_event = threading.Event()

        # Initialize Whisper model
        self._init_whisper_model()

        # Initialize VAD if enabled
        if self.vad_enabled:
            self._init_vad()

    def _init_whisper_model(self):
        """Initialize Whisper model with M4 optimization."""
        try:
            if self.use_mlx:
                # MLX Whisper - optimized for Apple Silicon
                import mlx_whisper
                console.print(f"[cyan]Initializing MLX Whisper (M4 optimized)...[/cyan]")
                console.print(f"[dim]Model: {self.model} | First run may download model files[/dim]")
                # MLX Whisper uses transcribe() directly, no need to preload
                self.whisper_model = mlx_whisper
                self.backend = "mlx"
                console.print("[green]✓ MLX backend ready (Metal GPU)[/green]")
            else:
                raise ImportError("Fallback to faster-whisper")
        except (ImportError, Exception) as e:
            # Fallback to faster-whisper
            logger.debug(f"MLX not available: {e}")
            from faster_whisper import WhisperModel
            console.print(f"[yellow]MLX not available, using faster-whisper[/yellow]")

            whisper_config = self.config.get('whisper', {})
            device = whisper_config.get('device', 'cpu')
            compute_type = whisper_config.get('compute_type', 'int8')

            self.whisper_model = WhisperModel(
                self.model,
                device=device,
                compute_type=compute_type
            )
            self.backend = "faster-whisper"
            console.print(f"[green]✓ faster-whisper loaded ({device}/{compute_type})[/green]")

    def _init_vad(self):
        """Initialize Voice Activity Detection."""
        try:
            import webrtcvad
            self.vad = webrtcvad.Vad(2)  # Aggressiveness 0-3 (2 = moderate)
            logger.info("✓ VAD enabled (will skip silence)")
        except ImportError:
            logger.warning("webrtcvad not available, VAD disabled")
            self.vad_enabled = False
            self.vad = None

    def _audio_callback(self, indata, frames, time_info, status):
        """Callback for audio stream."""
        if status:
            logger.warning(f"Audio status: {status}")

        # Add audio chunk to queue
        self.audio_queue.put(indata.copy())

    def _is_speech(self, audio_chunk: np.ndarray) -> bool:
        """Check if audio chunk contains speech using VAD."""
        if not self.vad_enabled or self.vad is None:
            return True

        try:
            # Convert to 16-bit PCM for VAD
            audio_int16 = (audio_chunk * 32767).astype(np.int16)
            audio_bytes = audio_int16.tobytes()

            # VAD requires specific frame sizes (10, 20, or 30ms)
            frame_duration = 30  # ms
            frame_size = int(self.sample_rate * frame_duration / 1000)

            # Check multiple frames
            num_frames = len(audio_int16) // frame_size
            speech_frames = 0

            for i in range(num_frames):
                start = i * frame_size
                end = start + frame_size
                frame = audio_bytes[start * 2:end * 2]  # 2 bytes per sample

                if len(frame) == frame_size * 2:
                    if self.vad.is_speech(frame, self.sample_rate):
                        speech_frames += 1

            # Consider speech if >30% of frames contain speech
            return speech_frames > num_frames * 0.3

        except Exception as e:
            logger.debug(f"VAD error: {e}")
            return True

    def _process_audio(self):
        """Background thread to process audio chunks."""
        audio_buffer = []
        buffer_duration = 0.0

        while not self.stop_event.is_set():
            try:
                # Get audio chunk with timeout
                chunk = self.audio_queue.get(timeout=0.1)

                # Flatten if stereo
                if chunk.ndim > 1:
                    chunk = chunk.mean(axis=1)

                # Check for speech
                if not self._is_speech(chunk):
                    continue

                # Add to buffer
                audio_buffer.append(chunk)
                buffer_duration += self.chunk_duration

                # Process when we have enough audio
                if buffer_duration >= 2.0:  # Process every 2 seconds for better context
                    audio_data = np.concatenate(audio_buffer)

                    # Transcribe
                    segment = self._transcribe_chunk(audio_data)

                    if segment and segment.text.strip():
                        self.vtt_segments.append(segment)

                        # Call callback if registered
                        if self.on_segment_callback:
                            self.on_segment_callback(segment)

                    # Reset buffer
                    audio_buffer = []
                    buffer_duration = 0.0

            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Audio processing error: {e}")

    def _transcribe_chunk(self, audio_data: np.ndarray) -> Optional[VTTSegment]:
        """Transcribe audio chunk to VTT segment."""
        try:
            current_time = time.time()
            offset = current_time - self.start_time if self.start_time else 0.0

            if self.backend == "mlx":
                # MLX Whisper transcription
                # Map standard model names to MLX HuggingFace repos
                # Source: https://huggingface.co/collections/mlx-community/whisper-663256f9964fbb1177db93dc
                mlx_model_map = {
                    'tiny': 'mlx-community/whisper-tiny-mlx',
                    'base': 'mlx-community/whisper-base-mlx',
                    'small': 'mlx-community/whisper-small-mlx',
                    'medium': 'mlx-community/whisper-medium-mlx',
                    'large': 'mlx-community/whisper-large-v3-mlx',
                    'large-v2': 'mlx-community/whisper-large-v2-mlx',
                    'large-v3': 'mlx-community/whisper-large-v3-mlx',
                    'large-v3-turbo': 'mlx-community/whisper-large-v3-turbo',
                }

                mlx_model = mlx_model_map.get(self.model, 'mlx-community/whisper-tiny-mlx')

                result = self.whisper_model.transcribe(
                    audio_data,
                    path_or_hf_repo=mlx_model,
                    language=self.language,
                    verbose=False
                )

                text = result.get("text", "").strip()

                # Filter out Whisper hallucinations (common YouTube artifacts)
                text = self._filter_hallucinations(text)

                if text:
                    return VTTSegment(
                        start=offset - len(audio_data) / self.sample_rate,
                        end=offset,
                        text=text,
                        confidence=1.0
                    )

            else:
                # Faster-whisper transcription
                segments, info = self.whisper_model.transcribe(
                    audio_data,
                    language=self.language,
                    vad_filter=True,
                    beam_size=5
                )

                # Combine segments
                texts = []
                for seg in segments:
                    texts.append(seg.text.strip())

                text = " ".join(texts)

                # Filter out Whisper hallucinations
                text = self._filter_hallucinations(text)

                if text:
                    return VTTSegment(
                        start=offset - len(audio_data) / self.sample_rate,
                        end=offset,
                        text=text,
                        confidence=1.0
                    )

        except Exception as e:
            logger.error(f"Transcription error: {e}")
            logger.exception("Details:")

        return None

    def _filter_hallucinations(self, text: str) -> str:
        """
        Filter out common Whisper hallucinations.

        Whisper is trained on YouTube videos and often hallucinates
        common video phrases when there's silence or noise.
        """
        if not text:
            return text

        # Common hallucinations (case-insensitive)
        hallucinations = [
            "thanks for watching",
            "thank you for watching",
            "please subscribe",
            "like and subscribe",
            "don't forget to subscribe",
            "see you next time",
            "bye bye",
            "goodbye",
            "you",  # Often appears alone in silence
            "[music]",
            "[Music]",
            "[MUSIC]",
            "(music)",
            "♪",
            "。",  # Chinese period (common artifact)
        ]

        text_lower = text.lower().strip()

        # Exact match removal
        for hallucination in hallucinations:
            if text_lower == hallucination.lower():
                logger.debug(f"Filtered hallucination: '{text}'")
                return ""

        # Remove if text starts/ends with hallucination
        for hallucination in hallucinations:
            if text_lower.startswith(hallucination.lower()):
                text = text[len(hallucination):].strip()
            if text_lower.endswith(hallucination.lower()):
                text = text[:-len(hallucination)].strip()

        # Filter very short transcriptions (likely noise)
        if len(text) <= 2:
            logger.debug(f"Filtered short text: '{text}'")
            return ""

        return text.strip()

    def start(self, device: Optional[str] = None):
        """Start real-time recording and transcription."""
        if self.is_recording:
            logger.warning("Already recording")
            return

        logger.info("Starting real-time VTT stream...")

        self.is_recording = True
        self.start_time = time.time()
        self.stop_event.clear()

        # Start audio stream
        self.stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            callback=self._audio_callback,
            blocksize=self.chunk_size,
            device=device,
            dtype=np.float32
        )
        self.stream.start()

        # Start processor thread
        self.processor_thread = threading.Thread(target=self._process_audio, daemon=True)
        self.processor_thread.start()

        logger.info("✓ Recording started")

    def stop(self):
        """Stop recording and transcription."""
        if not self.is_recording:
            return

        logger.info("Stopping real-time VTT stream...")

        self.is_recording = False
        self.stop_event.set()

        # Stop audio stream
        if self.stream:
            self.stream.stop()
            self.stream.close()
            self.stream = None

        # Wait for processor to finish
        if self.processor_thread:
            self.processor_thread.join(timeout=2.0)

        logger.info("✓ Recording stopped")

    def get_vtt(self) -> str:
        """Get full VTT output."""
        vtt = "WEBVTT\n\n"
        for segment in self.vtt_segments:
            vtt += segment.to_vtt()
        return vtt

    def save_vtt(self, output_path: Path):
        """Save VTT to file."""
        output_path.write_text(self.get_vtt(), encoding='utf-8')
        logger.info(f"VTT saved to {output_path}")

    def on_segment(self, callback: Callable[[VTTSegment], None]):
        """Register callback for new segments."""
        self.on_segment_callback = callback


def live_vtt_preview(
    model: str = "base",
    language: Optional[str] = None,
    duration: Optional[int] = None,
    output_path: Optional[Path] = None,
    config: Optional[Dict[str, Any]] = None,
    use_mlx: bool = True
):
    """
    Run live VTT preview with real-time display.

    Args:
        model: Whisper model size
        language: Language code
        duration: Recording duration (None = until Ctrl+C)
        output_path: Path to save VTT file
        config: Configuration dictionary
        use_mlx: Use MLX (GPU) or faster-whisper (CPU)
    """
    streamer = RealtimeVTTStream(
        model=model,
        language=language,
        use_mlx=use_mlx,
        vad_enabled=True,
        config=config
    )

    # Display state
    display_segments: List[str] = []

    def on_new_segment(segment: VTTSegment):
        """Handle new segment."""
        display_segments.append(f"[{segment._format_timestamp(segment.start)}] {segment.text}")

    streamer.on_segment(on_new_segment)

    # Start recording
    streamer.start()

    try:
        with Live(console=console, refresh_per_second=4) as live:
            start_time = time.time()

            while True:
                # Check duration limit
                if duration and (time.time() - start_time) >= duration:
                    break

                # Build display
                elapsed = time.time() - start_time

                display_text = Text()
                display_text.append(f"⏺ RECORDING ", style="bold red")
                display_text.append(f"({elapsed:.1f}s)\n\n", style="dim")

                # Show recent segments
                recent = display_segments[-10:]  # Last 10 segments
                for line in recent:
                    display_text.append(line + "\n", style="green")

                if not recent:
                    display_text.append("Listening... speak now!", style="dim yellow")

                panel = Panel(
                    display_text,
                    title=f"[bold cyan]Real-Time VTT ({streamer.backend})[/bold cyan]",
                    border_style="cyan"
                )

                live.update(panel)
                time.sleep(0.25)

    except KeyboardInterrupt:
        console.print("\n[yellow]Stopping...[/yellow]")

    finally:
        streamer.stop()

        # Save VTT
        if output_path:
            streamer.save_vtt(output_path)
            console.print(f"\n[green]✓ VTT saved to {output_path}[/green]")

        # Show stats
        num_segments = len(streamer.vtt_segments)
        total_duration = time.time() - start_time
        console.print(f"\n[dim]Processed {num_segments} segments in {total_duration:.1f}s[/dim]")
