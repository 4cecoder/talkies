"""
Batch transcription functionality.

Processes multiple audio files in a directory with progress tracking.
"""

from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
import logging
import fnmatch

from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn

from .transcription import transcribe_file, save_transcript, TranscriptionError

logger = logging.getLogger(__name__)
console = Console()


# Supported audio file extensions
AUDIO_EXTENSIONS = {".mp3", ".wav", ".flac", ".m4a", ".ogg", ".aac", ".wma", ".opus"}


@dataclass
class BatchResult:
    """Result of a batch transcription operation."""
    total: int
    successful: int
    failed: int
    skipped: int
    results: List[Dict[str, Any]]


def find_audio_files(
    input_dir: Path,
    pattern: str = "*",
    recursive: bool = False
) -> List[Path]:
    """Find audio files in a directory.

    Args:
        input_dir: Directory to search.
        pattern: Glob pattern to match (e.g., "*.mp3,*.wav" or "*").
        recursive: Search subdirectories.

    Returns:
        List of paths to audio files.
    """
    files = []

    # Parse pattern (supports comma-separated patterns)
    patterns = [p.strip() for p in pattern.split(",")]

    # Get all files
    if recursive:
        all_files = input_dir.rglob("*")
    else:
        all_files = input_dir.glob("*")

    for file_path in all_files:
        if not file_path.is_file():
            continue

        # Check extension
        if file_path.suffix.lower() not in AUDIO_EXTENSIONS:
            continue

        # Check pattern match
        matches = any(fnmatch.fnmatch(file_path.name, p) for p in patterns)
        if pattern == "*" or matches:
            files.append(file_path)

    return sorted(files)


def batch_transcribe(
    input_dir: Path,
    output_dir: Optional[Path] = None,
    recursive: bool = False,
    pattern: str = "*",
    format: str = "txt",
    model: str = "base",
    language: Optional[str] = None,
    improve: bool = False,
    config: Optional[Dict[str, Any]] = None,
) -> BatchResult:
    """Batch transcribe all audio files in a directory.

    Args:
        input_dir: Directory containing audio files.
        output_dir: Output directory. If None, uses input directory.
        recursive: Process subdirectories.
        pattern: File pattern to match (e.g., "*.mp3,*.wav").
        format: Output format (txt, srt, vtt, json).
        model: Whisper model name.
        language: Language code or None for auto-detect.
        improve: Improve transcripts with AI.
        config: Configuration dictionary.

    Returns:
        BatchResult with statistics and individual results.
    """
    if config is None:
        config = {}

    if output_dir is None:
        output_dir = input_dir

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Find audio files
    files = find_audio_files(input_dir, pattern, recursive)

    if not files:
        console.print(f"[yellow]No audio files found in {input_dir}[/yellow]")
        return BatchResult(total=0, successful=0, failed=0, skipped=0, results=[])

    console.print(f"Found [bold]{len(files)}[/bold] audio files to process")

    results = []
    successful = 0
    failed = 0
    skipped = 0

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console,
    ) as progress:
        task = progress.add_task("Transcribing...", total=len(files))

        for file_path in files:
            progress.update(task, description=f"Processing {file_path.name}")

            # Determine output path
            if recursive:
                # Preserve relative directory structure
                rel_path = file_path.relative_to(input_dir)
                out_dir = output_dir / rel_path.parent
                out_dir.mkdir(parents=True, exist_ok=True)
            else:
                out_dir = output_dir

            output_path = out_dir / file_path.with_suffix(f".{format}").name

            # Skip if output already exists
            if output_path.exists():
                logger.info(f"Skipping {file_path.name} - output exists")
                skipped += 1
                results.append({
                    "input": str(file_path),
                    "output": str(output_path),
                    "status": "skipped",
                    "error": None
                })
                progress.advance(task)
                continue

            try:
                # Transcribe
                result = transcribe_file(
                    file_path,
                    model=model,
                    language=language,
                    config=config,
                )

                # Improve with AI if requested
                if improve:
                    from .ai_services import improve_transcript
                    result["text"] = improve_transcript(result["text"], config)

                # Save output
                save_transcript(result, output_path, format)

                successful += 1
                results.append({
                    "input": str(file_path),
                    "output": str(output_path),
                    "status": "success",
                    "error": None,
                    "language": result.get("language"),
                    "duration": result.get("duration"),
                })

                logger.info(f"Transcribed {file_path.name} -> {output_path.name}")

            except TranscriptionError as e:
                failed += 1
                results.append({
                    "input": str(file_path),
                    "output": None,
                    "status": "failed",
                    "error": str(e)
                })
                console.print(f"[red]Error: {file_path.name} - {e}[/red]")
                logger.error(f"Failed to transcribe {file_path}: {e}")

            except Exception as e:
                failed += 1
                results.append({
                    "input": str(file_path),
                    "output": None,
                    "status": "failed",
                    "error": str(e)
                })
                console.print(f"[red]Error: {file_path.name} - {e}[/red]")
                logger.exception(f"Unexpected error transcribing {file_path}")

            progress.advance(task)

    # Print summary
    console.print()
    console.print(f"[bold]Batch transcription complete:[/bold]")
    console.print(f"  [green]Successful: {successful}[/green]")
    if failed:
        console.print(f"  [red]Failed: {failed}[/red]")
    if skipped:
        console.print(f"  [yellow]Skipped: {skipped}[/yellow]")

    return BatchResult(
        total=len(files),
        successful=successful,
        failed=failed,
        skipped=skipped,
        results=results
    )
