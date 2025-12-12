"""
Watch folder functionality for automatic transcription.

Monitors a directory for new audio files and transcribes them automatically.
"""

from pathlib import Path
from typing import Dict, Any, Optional, Set
from fnmatch import fnmatch
import logging
import time
import threading

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent
from rich.console import Console

from .transcription import transcribe_file, save_transcript, TranscriptionError
from .batch import AUDIO_EXTENSIONS

logger = logging.getLogger(__name__)
console = Console()


class AudioFileHandler(FileSystemEventHandler):
    """Handler for file system events on audio files."""

    def __init__(
        self,
        output_dir: Path,
        patterns: Set[str],
        format: str,
        model: str,
        language: Optional[str],
        improve: bool,
        config: Dict[str, Any]
    ):
        self.output_dir = output_dir
        self.patterns = patterns
        self.format = format
        self.model = model
        self.language = language
        self.improve = improve
        self.config = config
        self.processing: Set[Path] = set()
        self.lock = threading.Lock()

    def on_created(self, event):
        """Handle file creation events."""
        if event.is_directory:
            return

        file_path = Path(event.src_path)

        # Check if it's an audio file
        if not self._is_audio_file(file_path):
            return

        # Check pattern match
        if not self._matches_pattern(file_path.name):
            return

        # Avoid processing same file multiple times
        with self.lock:
            if file_path in self.processing:
                return
            self.processing.add(file_path)

        # Wait a bit for file to be fully written
        time.sleep(1)

        try:
            self._transcribe_file(file_path)
        finally:
            with self.lock:
                self.processing.discard(file_path)

    def _is_audio_file(self, file_path: Path) -> bool:
        """Check if file is a supported audio file."""
        return file_path.suffix.lower() in AUDIO_EXTENSIONS

    def _matches_pattern(self, filename: str) -> bool:
        """Check if filename matches any pattern."""
        if not self.patterns:
            return True
        return any(fnmatch(filename, p) for p in self.patterns)

    def _transcribe_file(self, audio_path: Path):
        """Transcribe a single file."""
        console.print(f"[cyan]New file detected:[/cyan] {audio_path.name}")

        output_path = self.output_dir / audio_path.with_suffix(f".{self.format}").name

        # Skip if output already exists
        if output_path.exists():
            console.print(f"[yellow]Skipping {audio_path.name} - output exists[/yellow]")
            return

        try:
            result = transcribe_file(
                audio_path,
                model=self.model,
                language=self.language,
                config=self.config,
            )

            # Improve with AI if requested
            if self.improve:
                from .ai_services import improve_transcript
                result["text"] = improve_transcript(result["text"], self.config)

            save_transcript(result, output_path, self.format)
            console.print(f"[green]Transcribed:[/green] {audio_path.name} -> {output_path.name}")
            logger.info(f"Transcribed {audio_path} -> {output_path}")

        except TranscriptionError as e:
            console.print(f"[red]Error transcribing {audio_path.name}: {e}[/red]")
            logger.error(f"Failed to transcribe {audio_path}: {e}")

        except Exception as e:
            console.print(f"[red]Unexpected error transcribing {audio_path.name}: {e}[/red]")
            logger.exception(f"Unexpected error transcribing {audio_path}")


def watch_folder(
    folder: Path,
    output_dir: Optional[Path] = None,
    pattern: str = "*",
    format: str = "txt",
    model: str = "base",
    language: Optional[str] = None,
    improve: bool = False,
    config: Optional[Dict[str, Any]] = None,
) -> None:
    """Watch a folder for new audio files and transcribe them.

    Args:
        folder: Directory to watch.
        output_dir: Output directory. If None, uses watched directory.
        pattern: File patterns to match (comma-separated, e.g., "*.mp3,*.wav").
        format: Output format (txt, srt, vtt, json).
        model: Whisper model name.
        language: Language code or None for auto-detect.
        improve: Improve transcripts with AI.
        config: Configuration dictionary.
    """
    if config is None:
        config = {}

    folder = Path(folder)
    if not folder.exists():
        raise FileNotFoundError(f"Directory not found: {folder}")

    if output_dir is None:
        output_dir = folder
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    # Parse patterns
    patterns = {p.strip() for p in pattern.split(",")} if pattern != "*" else set()

    event_handler = AudioFileHandler(
        output_dir=output_dir,
        patterns=patterns,
        format=format,
        model=model,
        language=language,
        improve=improve,
        config=config
    )

    observer = Observer()
    observer.schedule(event_handler, str(folder), recursive=True)
    observer.start()

    console.print(f"[bold]Watching folder:[/bold] {folder}")
    console.print(f"[bold]Output directory:[/bold] {output_dir}")
    console.print(f"[bold]Model:[/bold] {model}")
    console.print(f"[bold]Format:[/bold] {format}")
    if patterns:
        console.print(f"[bold]Patterns:[/bold] {', '.join(patterns)}")
    console.print()
    console.print("[dim]Press Ctrl+C to stop[/dim]")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        console.print("\n[yellow]Stopping watcher...[/yellow]")
        observer.stop()

    observer.join()
    console.print("[green]Watcher stopped[/green]")
