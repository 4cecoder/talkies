#!/usr/bin/env python3
"""
Whisper CLI - A fast, modular CLI tool for audio transcription.

Commands:
    transcribe  Transcribe a single audio file
    batch       Batch transcribe multiple files
    watch       Watch a folder for new audio files
    record      Record audio from microphone
    youtube     Transcribe a YouTube video
    live        Real-time VTT streaming (blazing fast on M4)
    system      Show system information
    models      Manage model downloads
    config      Manage configuration
    tui         Launch interactive TUI
"""

import click
from pathlib import Path
import logging
import sys

from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeRemainingColumn
from rich.table import Table
from rich.live import Live

from .config import load_config, save_config, create_default_config, get_config_path, ConfigError
from .transcription import transcribe_file, save_transcript, TranscriptionError
from .batch import batch_transcribe
from .watch import watch_folder
from .record import record_audio, list_audio_devices, RecordingError
from .ai_services import improve_transcript, check_ai_services
from .youtube import transcribe_youtube
from .system_detect import print_system_info, get_recommended_config
from .model_downloader import ModelDownloadManager, DownloadStatus
from .realtime import live_vtt_preview

console = Console()
logger = logging.getLogger(__name__)


def setup_logging(verbose: bool = False):
    """Configure logging based on verbosity."""
    level = logging.DEBUG if verbose else logging.WARNING
    logging.basicConfig(
        level=level,
        format="%(levelname)s: %(message)s",
        handlers=[logging.StreamHandler()]
    )


@click.group()
@click.option("--config", "config_path", default=None, help="Path to config file")
@click.option("-v", "--verbose", is_flag=True, help="Enable verbose output")
@click.pass_context
def cli(ctx, config_path, verbose):
    """Whisper CLI - Fast audio transcription tool."""
    ctx.ensure_object(dict)
    setup_logging(verbose)

    try:
        config_file = Path(config_path).expanduser() if config_path else None
        ctx.obj["config"] = load_config(config_file)
    except ConfigError as e:
        console.print(f"[red]Configuration error: {e}[/red]")
        sys.exit(1)


@cli.command()
@click.argument("audio_file", type=click.Path(exists=True))
@click.option("--model", "-m", default=None, help="Whisper model (tiny, base, small, medium, large-v2, large-v3)")
@click.option("--language", "-l", help="Language code (auto-detect if not specified)")
@click.option("--output", "-o", type=click.Path(), help="Output file path")
@click.option("--format", "-f", "fmt", default="txt", type=click.Choice(["txt", "srt", "vtt", "json"]))
@click.option("--translate", is_flag=True, help="Translate to English")
@click.option("--improve", is_flag=True, help="Improve with AI (requires API key)")
@click.option("--speakers", is_flag=True, help="Enable speaker detection")
@click.pass_context
def transcribe(ctx, audio_file, model, language, output, fmt, translate, improve, speakers):
    """Transcribe a single audio file."""
    config = ctx.obj["config"]
    audio_path = Path(audio_file)

    # Use config defaults if not specified
    if model is None:
        model = config.get("whisper", {}).get("model", "base")

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TimeRemainingColumn(),
        console=console,
    ) as progress:
        task = progress.add_task(f"Transcribing {audio_path.name}...", total=None)

        try:
            result = transcribe_file(
                audio_path,
                model=model,
                language=language,
                config=config,
                translate="en" if translate else None,
                speakers=speakers,
            )

            if improve:
                progress.update(task, description="Improving with AI...")
                result["text"] = improve_transcript(result["text"], config)

            # Determine output path
            output_path = Path(output) if output else audio_path.with_suffix(f".{fmt}")
            save_transcript(result, output_path, fmt)

            progress.update(task, completed=True)

        except TranscriptionError as e:
            console.print(f"[red]Transcription error: {e}[/red]")
            raise click.Abort()
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            logger.exception("Transcription failed")
            raise click.Abort()

    console.print(f"[green]Saved to {output_path}[/green]")

    # Show detected language
    if result.get("language"):
        console.print(f"[dim]Detected language: {result['language']}[/dim]")


@cli.command()
@click.argument("input_dir", type=click.Path(exists=True))
@click.option("--output-dir", "-o", type=click.Path(), help="Output directory")
@click.option("--recursive", "-r", is_flag=True, help="Process subdirectories")
@click.option("--pattern", "-p", default="*", help="File pattern (e.g., '*.mp3,*.wav')")
@click.option("--format", "-f", "fmt", default="txt", type=click.Choice(["txt", "srt", "vtt", "json"]))
@click.option("--model", "-m", default=None, help="Whisper model")
@click.option("--improve", is_flag=True, help="Improve with AI")
@click.pass_context
def batch(ctx, input_dir, output_dir, recursive, pattern, fmt, model, improve):
    """Batch transcribe multiple files."""
    config = ctx.obj["config"]

    if model is None:
        model = config.get("whisper", {}).get("model", "base")

    result = batch_transcribe(
        Path(input_dir),
        output_dir=Path(output_dir) if output_dir else None,
        recursive=recursive,
        pattern=pattern,
        format=fmt,
        model=model,
        improve=improve,
        config=config,
    )


@cli.command()
@click.argument("folder", type=click.Path(exists=True))
@click.option("--output-dir", "-o", type=click.Path(), help="Output directory")
@click.option("--pattern", "-p", default="*", help="File pattern")
@click.option("--format", "-f", "fmt", default="txt", type=click.Choice(["txt", "srt", "vtt", "json"]))
@click.option("--model", "-m", default=None, help="Whisper model")
@click.option("--improve", is_flag=True, help="Improve with AI")
@click.pass_context
def watch(ctx, folder, output_dir, pattern, fmt, model, improve):
    """Watch a folder for new audio files."""
    config = ctx.obj["config"]

    if model is None:
        model = config.get("whisper", {}).get("model", "base")

    watch_folder(
        Path(folder),
        output_dir=Path(output_dir) if output_dir else None,
        pattern=pattern,
        format=fmt,
        model=model,
        improve=improve,
        config=config,
    )


@cli.command()
@click.option("--duration", "-d", default=None, type=int, help="Recording duration (seconds)")
@click.option("--output", "-o", default="recording.wav", help="Output file path")
@click.option("--device", help="Audio device name")
@click.option("--list-devices", is_flag=True, help="List available audio devices")
@click.pass_context
def record(ctx, duration, output, device, list_devices):
    """Record audio from microphone."""
    if list_devices:
        devices = list_audio_devices()
        if not devices:
            console.print("[yellow]No audio input devices found[/yellow]")
            return

        table = Table(title="Audio Input Devices")
        table.add_column("Index", style="cyan")
        table.add_column("Name", style="green")
        table.add_column("Channels", style="yellow")
        table.add_column("Backend", style="magenta")

        for dev in devices:
            table.add_row(
                str(dev["index"]),
                dev["name"],
                str(dev["channels"]),
                dev["backend"]
            )

        console.print(table)
        return

    config = ctx.obj["config"]

    try:
        output_path = record_audio(
            Path(output),
            duration=duration,
            device=device,
            config=config
        )
    except RecordingError as e:
        console.print(f"[red]Recording error: {e}[/red]")
        raise click.Abort()


@cli.command()
@click.argument("url")
@click.option("--output", "-o", type=click.Path(), help="Output file path")
@click.option("--format", "-f", "fmt", default="txt", type=click.Choice(["txt", "srt", "vtt", "json"]))
@click.option("--model", "-m", default=None, help="Whisper model")
@click.option("--improve", is_flag=True, help="Improve with AI")
@click.pass_context
def youtube(ctx, url, output, fmt, model, improve):
    """Transcribe a YouTube video."""
    config = ctx.obj["config"]

    if model is None:
        model = config.get("whisper", {}).get("model", "base")

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Downloading YouTube audio...", total=None)

        try:
            result = transcribe_youtube(url, model=model, config=config)

            if improve:
                progress.update(task, description="Improving with AI...")
                result["text"] = improve_transcript(result["text"], config)

            output_path = Path(output) if output else Path("youtube_transcript").with_suffix(f".{fmt}")
            save_transcript(result, output_path, fmt)

            progress.update(task, completed=True)

        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            raise click.Abort()

    console.print(f"[green]Saved to {output_path}[/green]")


@cli.command()
@click.option("--recommend", is_flag=True, help="Show recommended configuration")
@click.option("--ai-status", is_flag=True, help="Check AI service availability")
@click.pass_context
def system(ctx, recommend, ai_status):
    """Show system information and capabilities."""
    if ai_status:
        config = ctx.obj["config"]
        console.print("[bold]AI Service Status:[/bold]")

        status = check_ai_services(config)
        for service, available in status.items():
            icon = "[green]✓[/green]" if available else "[red]✗[/red]"
            console.print(f"  {icon} {service.capitalize()}")
        return

    if recommend:
        console.print("[bold cyan]Recommended Configuration:[/bold cyan]")
        recommended = get_recommended_config()
        if recommended:
            for section, settings in recommended.items():
                console.print(f"\n[{section}]")
                for key, value in settings.items():
                    console.print(f'  {key} = "{value}"')
        else:
            console.print("No specific recommendations available.")
    else:
        print_system_info()


@cli.group()
def models():
    """Manage model downloads."""
    pass


@models.command("download")
@click.argument("model_name")
@click.option("--type", "model_type", type=click.Choice(["whisper", "ollama"]), default="whisper")
@click.option("--wait", is_flag=True, help="Wait for download to complete")
@click.pass_context
def download_model(ctx, model_name, model_type, wait):
    """Download a model."""
    config = ctx.obj["config"]
    manager = ModelDownloadManager()

    if model_type == "whisper":
        task = manager.download_whisper_model(model_name)
    else:
        ollama_url = config.get("ai_services", {}).get("ollama_url", "http://localhost:11434")
        task = manager.download_ollama_model(model_name, ollama_url=ollama_url)

    if wait:
        _display_download_progress(manager, model_name)
        success = manager.wait_for_download(model_name)
        if success:
            console.print(f"[green]✓ Model {model_name} downloaded[/green]")
        else:
            console.print(f"[red]✗ Download failed[/red]")
            raise click.Abort()
    else:
        console.print(f"[green]Download started. Use 'models status' to check progress.[/green]")


@models.command("status")
@click.argument("model_name", required=False)
@click.option("--all", "show_all", is_flag=True, help="Show all downloads")
def model_status(model_name, show_all):
    """Show download status."""
    manager = ModelDownloadManager()

    if show_all or not model_name:
        tasks = manager.list_downloads()
        if not tasks:
            console.print("[yellow]No active downloads[/yellow]")
            return

        table = Table(title="Download Status")
        table.add_column("Model", style="cyan")
        table.add_column("Type", style="magenta")
        table.add_column("Status", style="green")
        table.add_column("Progress", style="yellow")

        for task in tasks:
            status_icon = {
                DownloadStatus.PENDING: "⏳",
                DownloadStatus.DOWNLOADING: "⬇️",
                DownloadStatus.PAUSED: "⏸️",
                DownloadStatus.COMPLETED: "✓",
                DownloadStatus.VERIFIED: "✓",
                DownloadStatus.FAILED: "✗",
                DownloadStatus.VERIFYING: "🔍"
            }.get(task.status, "?")

            table.add_row(
                task.model_name,
                task.model_type,
                f"{status_icon} {task.status.value}",
                f"{task.progress:.1f}%"
            )

        console.print(table)
    else:
        task = manager.get_status(model_name)
        if not task:
            console.print(f"[yellow]No download found for {model_name}[/yellow]")
            return

        console.print(f"\n[bold]Model:[/bold] {task.model_name}")
        console.print(f"[bold]Status:[/bold] {task.status.value}")
        console.print(f"[bold]Progress:[/bold] {task.progress:.1f}%")
        if task.error_message:
            console.print(f"[red]Error:[/red] {task.error_message}")


@models.command("pause")
@click.argument("model_name")
def pause_download(model_name):
    """Pause a download."""
    manager = ModelDownloadManager()
    if manager.pause_download(model_name):
        console.print(f"[green]Paused {model_name}[/green]")
    else:
        console.print(f"[red]Failed to pause[/red]")


@models.command("resume")
@click.argument("model_name")
def resume_download(model_name):
    """Resume a paused download."""
    manager = ModelDownloadManager()
    if manager.resume_download(model_name):
        console.print(f"[green]Resumed {model_name}[/green]")
    else:
        console.print(f"[red]Failed to resume[/red]")


@models.command("cancel")
@click.argument("model_name")
def cancel_download(model_name):
    """Cancel a download."""
    manager = ModelDownloadManager()
    if manager.cancel_download(model_name):
        console.print(f"[green]Cancelled {model_name}[/green]")
    else:
        console.print(f"[red]Failed to cancel[/red]")


@models.command("list")
def list_models():
    """List downloaded models."""
    manager = ModelDownloadManager()
    tasks = manager.list_downloads()

    completed = [t for t in tasks if t.status in [DownloadStatus.COMPLETED, DownloadStatus.VERIFIED]]
    downloading = [t for t in tasks if t.status == DownloadStatus.DOWNLOADING]
    paused = [t for t in tasks if t.status == DownloadStatus.PAUSED]

    if completed:
        console.print("\n[bold green]Ready:[/bold green]")
        for task in completed:
            console.print(f"  • {task.model_name} ({task.model_type})")

    if downloading:
        console.print("\n[bold yellow]Downloading:[/bold yellow]")
        for task in downloading:
            console.print(f"  • {task.model_name} - {task.progress:.1f}%")

    if paused:
        console.print("\n[bold blue]Paused:[/bold blue]")
        for task in paused:
            console.print(f"  • {task.model_name}")

    if not tasks:
        console.print("[yellow]No models found[/yellow]")


@cli.group()
def config():
    """Manage configuration."""
    pass


@config.command("init")
@click.option("--force", is_flag=True, help="Overwrite existing config")
def config_init(force):
    """Create default configuration file."""
    config_path = get_config_path()

    if config_path.exists() and not force:
        console.print(f"[yellow]Config already exists at {config_path}[/yellow]")
        console.print("Use --force to overwrite")
        return

    if force and config_path.exists():
        config_path.unlink()

    try:
        path = create_default_config()
        console.print(f"[green]Created config at {path}[/green]")
    except ConfigError as e:
        console.print(f"[red]Error: {e}[/red]")


@config.command("show")
@click.pass_context
def config_show(ctx):
    """Show current configuration."""
    import json
    config = ctx.obj["config"]
    console.print_json(json.dumps(config, indent=2, default=str))


@config.command("path")
def config_path():
    """Show configuration file path."""
    console.print(get_config_path())


@cli.command()
def tui():
    """Launch interactive TUI interface."""
    from .tui import run_tui
    run_tui()


@cli.command()
@click.option("--model", "-m", default="medium", help="Whisper model (tiny, base, small, medium, large)")
@click.option("--language", "-l", help="Language code (auto-detect if not specified)")
@click.option("--duration", "-d", type=int, help="Recording duration in seconds (Ctrl+C to stop if not specified)")
@click.option("--output", "-o", type=click.Path(), help="Output VTT file path")
@click.option("--cpu", is_flag=True, help="Use CPU (faster-whisper) instead of GPU (MLX)")
@click.option("--gui", is_flag=True, help="Launch web-based GUI interface")
@click.pass_context
def live(ctx, model, language, duration, output, cpu, gui):
    """Real-time VTT streaming with blazing-fast transcription (optimized for M4)."""
    config = ctx.obj["config"]
    output_path = Path(output) if output else None

    # Check if GUI mode requested
    if gui:
        from .gui import launch_gui
        console.print("[bold cyan]Launching native desktop GUI...[/bold cyan]")
        launch_gui(model=model, language=language, config=config, use_mlx=not cpu)
        return

    # CLI mode with live preview
    console.print("[bold cyan]Starting real-time VTT stream...[/bold cyan]")
    console.print(f"[dim]Model: {model} | Language: {language or 'auto'}[/dim]")
    if cpu:
        console.print("[dim]Backend: CPU (faster-whisper)[/dim]")
    else:
        console.print("[dim]Backend: GPU (MLX)[/dim]")
    console.print("[dim]Hallucination filter: ON (filters 'Thanks for watching' etc.)[/dim]")
    console.print("[dim]Press Ctrl+C to stop[/dim]\n")

    try:
        live_vtt_preview(
            model=model,
            language=language,
            duration=duration,
            output_path=output_path,
            config=config,
            use_mlx=not cpu  # Use MLX unless --cpu flag is set
        )
    except KeyboardInterrupt:
        console.print("\n[yellow]Stopped by user[/yellow]")
    except Exception as e:
        console.print(f"\n[red]Error: {e}[/red]")
        logger.exception("Live VTT failed")
        raise click.Abort()


def _display_download_progress(manager: ModelDownloadManager, model_name: str):
    """Display real-time download progress."""
    import time

    with Live(console=console, refresh_per_second=2) as live:
        while True:
            task = manager.get_status(model_name)
            if not task:
                break

            if task.status in [DownloadStatus.COMPLETED, DownloadStatus.VERIFIED, DownloadStatus.FAILED]:
                break

            bar_width = 40
            filled = int(task.progress / 100 * bar_width)
            bar = "█" * filled + "░" * (bar_width - filled)

            speed_str = f"{task.speed / 1024 / 1024:.1f} MB/s" if task.speed > 0 else ""

            display = f"[{bar}] {task.progress:.1f}%  {speed_str}"
            live.update(display)

            time.sleep(0.5)


def main():
    """Entry point."""
    cli()


if __name__ == "__main__":
    main()
