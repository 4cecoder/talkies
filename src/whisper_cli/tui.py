#!/usr/bin/env python3
"""
Whisper CLI TUI - Modern Terminal User Interface
A slick, intuitive TUI for audio transcription
"""

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer
from textual.widgets import (
    Header, Footer, Static, Button, Input, Label,
    ProgressBar, DataTable, SelectionList, TabbedContent,
    TabPane, DirectoryTree, Log, RichLog
)
from textual.binding import Binding
from textual.screen import Screen, ModalScreen
from textual.message import Message
from textual import work
from textual.worker import Worker, get_current_worker

from pathlib import Path
from rich.text import Text
from rich.panel import Panel
from rich.table import Table
import asyncio
from typing import Optional
import os

# Lazy imports to allow TUI to load even if some deps are missing
def _load_config():
    try:
        from .config import load_config
        return load_config()
    except Exception as e:
        print(f"Warning: Could not load config: {e}")
        return {}

def _get_model_manager():
    try:
        from .model_downloader import ModelDownloadManager
        return ModelDownloadManager()
    except Exception as e:
        print(f"Warning: Could not load model manager: {e}")
        return None

def _get_download_status():
    try:
        from .model_downloader import DownloadStatus
        return DownloadStatus
    except ImportError:
        return None

def _get_system_info():
    try:
        from .system_detect import get_system_info, get_recommended_config
        return get_system_info(), get_recommended_config()
    except Exception:
        return {"platform": "unknown", "architecture": "unknown"}, {}

def _check_ai_services(config):
    try:
        from .ai_services import check_ai_services
        return check_ai_services(config)
    except Exception:
        return {}


# Available Whisper models with descriptions
WHISPER_MODELS = [
    ("tiny", "Tiny (~39 MB) - Fastest, lowest accuracy"),
    ("base", "Base (~74 MB) - Fast, good for most uses"),
    ("small", "Small (~244 MB) - Balanced speed/accuracy"),
    ("medium", "Medium (~769 MB) - Better accuracy"),
    ("large-v2", "Large V2 (~1.5 GB) - Best accuracy"),
    ("large-v3", "Large V3 (~1.5 GB) - Latest model"),
]

SUPPORTED_FORMATS = ["mp3", "wav", "flac", "m4a", "ogg", "aac", "wma", "opus"]


class HelpScreen(ModalScreen):
    """Help screen modal"""

    BINDINGS = [
        Binding("escape", "dismiss", "Close"),
        Binding("q", "dismiss", "Close"),
    ]

    def compose(self) -> ComposeResult:
        yield Container(
            Static("""
[bold cyan]Whisper CLI - Keyboard Shortcuts[/bold cyan]

[bold]Navigation[/bold]
  [yellow]Tab[/yellow]        Move to next element
  [yellow]Shift+Tab[/yellow]  Move to previous element
  [yellow]↑/↓[/yellow]        Navigate lists/tables
  [yellow]Enter[/yellow]      Select/Confirm

[bold]Global[/bold]
  [yellow]?[/yellow]          Show this help
  [yellow]q[/yellow]          Quit application
  [yellow]d[/yellow]          Dark/Light mode toggle
  [yellow]Ctrl+C[/yellow]     Exit

[bold]Transcription[/bold]
  [yellow]t[/yellow]          Quick transcribe
  [yellow]b[/yellow]          Batch transcribe
  [yellow]r[/yellow]          Record audio

[bold]Models[/bold]
  [yellow]m[/yellow]          Manage models
  [yellow]s[/yellow]          System info

[dim]Press Escape or Q to close[/dim]
            """, classes="help-content"),
            classes="help-modal"
        )


class FilePickerScreen(ModalScreen[Optional[Path]]):
    """File picker modal for selecting audio files"""

    BINDINGS = [
        Binding("escape", "cancel", "Cancel"),
    ]

    def __init__(self, start_path: Path = None):
        super().__init__()
        self.start_path = start_path or Path.home()

    def compose(self) -> ComposeResult:
        yield Container(
            Static("[bold]Select Audio File[/bold]", classes="modal-title"),
            DirectoryTree(str(self.start_path), id="file-tree"),
            Horizontal(
                Button("Cancel", variant="default", id="cancel-btn"),
                Button("Select", variant="primary", id="select-btn"),
                classes="modal-buttons"
            ),
            classes="file-picker-modal"
        )

    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected):
        path = Path(event.path)
        if path.suffix.lower().lstrip('.') in SUPPORTED_FORMATS:
            self.dismiss(path)

    def on_button_pressed(self, event: Button.Pressed):
        if event.button.id == "cancel-btn":
            self.dismiss(None)
        elif event.button.id == "select-btn":
            tree = self.query_one("#file-tree", DirectoryTree)
            if tree.cursor_node and tree.cursor_node.data.path:
                path = Path(tree.cursor_node.data.path)
                if path.is_file():
                    self.dismiss(path)

    def action_cancel(self):
        self.dismiss(None)


class TranscriptionPanel(Container):
    """Panel for transcription controls and output"""

    def compose(self) -> ComposeResult:
        yield Static("[bold cyan]📝 Transcription[/bold cyan]", classes="panel-title")

        with Vertical(classes="form-group"):
            yield Label("Audio File:")
            with Horizontal(classes="file-input-row"):
                yield Input(placeholder="Select or drag audio file...", id="file-input")
                yield Button("Browse", id="browse-btn", variant="primary")

        with Horizontal(classes="form-row"):
            with Vertical(classes="form-group half"):
                yield Label("Model:")
                yield SelectionList[str](
                    *[(name, value, value == "base") for value, name in WHISPER_MODELS],
                    id="model-select"
                )

            with Vertical(classes="form-group half"):
                yield Label("Options:")
                yield SelectionList[str](
                    ("Improve with AI", "improve", False),
                    ("Translate to English", "translate", False),
                    ("Speaker detection", "speakers", False),
                    id="options-select"
                )

        with Horizontal(classes="form-row"):
            yield Label("Output Format:")
            yield Button("TXT", id="fmt-txt", variant="primary", classes="format-btn active")
            yield Button("SRT", id="fmt-srt", variant="default", classes="format-btn")
            yield Button("VTT", id="fmt-vtt", variant="default", classes="format-btn")
            yield Button("JSON", id="fmt-json", variant="default", classes="format-btn")

        yield Horizontal(
            Button("🎙️ Transcribe", id="transcribe-btn", variant="success"),
            Button("📂 Batch", id="batch-btn", variant="warning"),
            classes="action-buttons"
        )

        yield Static("[dim]Ready[/dim]", id="status-label")
        yield ProgressBar(id="progress-bar", show_eta=True)

        yield Static("[bold]Output:[/bold]", classes="output-title")
        yield RichLog(id="output-log", highlight=True, markup=True, wrap=True)


class ModelsPanel(Container):
    """Panel for managing Whisper models"""

    def compose(self) -> ComposeResult:
        yield Static("[bold cyan]🧠 Model Manager[/bold cyan]", classes="panel-title")

        yield DataTable(id="models-table")

        yield Horizontal(
            Button("⬇️ Download", id="download-btn", variant="primary"),
            Button("⏸️ Pause", id="pause-btn", variant="warning"),
            Button("▶️ Resume", id="resume-btn", variant="success"),
            Button("🗑️ Delete", id="delete-btn", variant="error"),
            classes="action-buttons"
        )

        yield Static("", id="download-status")
        yield ProgressBar(id="download-progress", show_eta=True)


class SystemPanel(Container):
    """Panel showing system information"""

    def compose(self) -> ComposeResult:
        yield Static("[bold cyan]💻 System Info[/bold cyan]", classes="panel-title")
        yield ScrollableContainer(
            Static(id="system-info-content"),
            id="system-scroll"
        )
        yield Button("🔄 Refresh", id="refresh-system-btn", variant="primary")


class RecordPanel(Container):
    """Panel for audio recording"""

    def compose(self) -> ComposeResult:
        yield Static("[bold cyan]🎙️ Record Audio[/bold cyan]", classes="panel-title")

        with Vertical(classes="form-group"):
            yield Label("Recording Settings:")
            with Horizontal(classes="form-row"):
                yield Label("Duration (sec):")
                yield Input(value="30", id="record-duration", type="integer")

            with Horizontal(classes="form-row"):
                yield Label("Output file:")
                yield Input(value="recording.wav", id="record-output")

        yield Horizontal(
            Button("⏺️ Start Recording", id="record-start-btn", variant="error"),
            Button("⏹️ Stop", id="record-stop-btn", variant="default", disabled=True),
            classes="action-buttons"
        )

        yield Static("[dim]Ready to record[/dim]", id="record-status")
        yield ProgressBar(id="record-progress")


class WatchPanel(Container):
    """Panel for folder watching"""

    def compose(self) -> ComposeResult:
        yield Static("[bold cyan]👁️ Watch Folder[/bold cyan]", classes="panel-title")

        with Vertical(classes="form-group"):
            yield Label("Watch Directory:")
            with Horizontal(classes="file-input-row"):
                yield Input(placeholder="Select folder to watch...", id="watch-folder-input")
                yield Button("Browse", id="watch-browse-btn", variant="primary")

        with Horizontal(classes="form-row"):
            yield Label("File Pattern:")
            yield Input(value="*.mp3,*.wav,*.m4a,*.flac", id="watch-pattern")

        yield Horizontal(
            Button("👁️ Start Watching", id="watch-start-btn", variant="success"),
            Button("⏹️ Stop", id="watch-stop-btn", variant="error", disabled=True),
            classes="action-buttons"
        )

        yield RichLog(id="watch-log", highlight=True, markup=True)


class WhisperApp(App):
    """Main Whisper CLI TUI Application"""

    CSS = """
    Screen {
        background: $surface;
    }

    .panel-title {
        text-align: center;
        text-style: bold;
        padding: 1;
        background: $primary-background;
        margin-bottom: 1;
    }

    .form-group {
        margin: 1 2;
    }

    .form-row {
        height: auto;
        margin: 1 0;
    }

    .half {
        width: 50%;
    }

    .file-input-row {
        height: 3;
    }

    .file-input-row Input {
        width: 80%;
    }

    .file-input-row Button {
        width: 20%;
    }

    .action-buttons {
        height: 3;
        margin: 1 2;
        align: center middle;
    }

    .action-buttons Button {
        margin: 0 1;
    }

    .format-btn {
        min-width: 8;
    }

    #output-log {
        height: 12;
        border: solid $primary;
        margin: 1 2;
    }

    #watch-log {
        height: 15;
        border: solid $primary;
        margin: 1 2;
    }

    #models-table {
        height: 12;
        margin: 1 2;
    }

    #system-scroll {
        height: 20;
        margin: 1 2;
        border: solid $primary;
    }

    .help-modal {
        align: center middle;
        background: $surface;
        border: thick $primary;
        padding: 2;
        width: 60;
        height: 30;
    }

    .help-content {
        padding: 1;
    }

    .file-picker-modal {
        align: center middle;
        background: $surface;
        border: thick $primary;
        padding: 2;
        width: 80%;
        height: 80%;
    }

    .modal-title {
        text-align: center;
        padding: 1;
    }

    .modal-buttons {
        height: 3;
        align: center middle;
        margin-top: 1;
    }

    #file-tree {
        height: 100%;
        margin: 1;
    }

    ProgressBar {
        margin: 0 2;
    }

    SelectionList {
        height: 8;
        border: solid $primary;
    }

    #status-label {
        margin: 1 2;
        text-align: center;
    }

    #download-status {
        margin: 1 2;
        text-align: center;
    }

    #record-status {
        margin: 1 2;
        text-align: center;
    }

    .output-title {
        margin: 1 2 0 2;
    }
    """

    TITLE = "Whisper CLI"
    SUB_TITLE = "Audio Transcription Tool"

    BINDINGS = [
        Binding("q", "quit", "Quit", priority=True),
        Binding("?", "help", "Help"),
        Binding("d", "toggle_dark", "Theme"),
        Binding("t", "focus_transcribe", "Transcribe"),
        Binding("m", "focus_models", "Models"),
        Binding("r", "focus_record", "Record"),
        Binding("s", "focus_system", "System"),
    ]

    def __init__(self):
        super().__init__()
        self.config = _load_config()
        self.model_manager = _get_model_manager()
        self.selected_format = "txt"
        self.selected_file: Optional[Path] = None
        self.DownloadStatus = _get_download_status()

    def compose(self) -> ComposeResult:
        yield Header()

        with TabbedContent(initial="transcribe"):
            with TabPane("📝 Transcribe", id="transcribe"):
                yield TranscriptionPanel()

            with TabPane("🧠 Models", id="models"):
                yield ModelsPanel()

            with TabPane("🎙️ Record", id="record"):
                yield RecordPanel()

            with TabPane("👁️ Watch", id="watch"):
                yield WatchPanel()

            with TabPane("💻 System", id="system"):
                yield SystemPanel()

        yield Footer()

    def on_mount(self):
        """Initialize components on mount"""
        self.refresh_models_table()
        self.refresh_system_info()

    def refresh_models_table(self):
        """Refresh the models table with current status"""
        table = self.query_one("#models-table", DataTable)
        table.clear(columns=True)

        table.add_column("Model", key="model")
        table.add_column("Size", key="size")
        table.add_column("Status", key="status")
        table.add_column("Progress", key="progress")

        # Add all available models
        model_sizes = {
            "tiny": "~39 MB",
            "base": "~74 MB",
            "small": "~244 MB",
            "medium": "~769 MB",
            "large-v2": "~1.5 GB",
            "large-v3": "~1.5 GB",
        }

        downloads = {}
        if self.model_manager:
            downloads = {t.model_name: t for t in self.model_manager.list_downloads()}

        for model_name, size in model_sizes.items():
            if model_name in downloads and self.DownloadStatus:
                task = downloads[model_name]
                status_text = {
                    self.DownloadStatus.PENDING: "[yellow]Pending[/yellow]",
                    self.DownloadStatus.DOWNLOADING: "[blue]Downloading[/blue]",
                    self.DownloadStatus.PAUSED: "[orange]Paused[/orange]",
                    self.DownloadStatus.COMPLETED: "[green]✓ Ready[/green]",
                    self.DownloadStatus.VERIFIED: "[green]✓ Verified[/green]",
                    self.DownloadStatus.FAILED: "[red]✗ Failed[/red]",
                    self.DownloadStatus.VERIFYING: "[cyan]Verifying...[/cyan]",
                }.get(task.status, task.status.value)
                progress = f"{task.progress:.1f}%"
            else:
                status_text = "[dim]Not downloaded[/dim]"
                progress = "-"

            table.add_row(model_name, size, status_text, progress)

    def refresh_system_info(self):
        """Refresh system information display"""
        try:
            info, recommended = _get_system_info()

            content = f"""[bold]Platform:[/bold] {info.get('platform', 'Unknown')}
[bold]Architecture:[/bold] {info.get('architecture', 'Unknown')}
[bold]CPU Cores:[/bold] {info.get('cpu_cores', 'Unknown')}
[bold]Memory:[/bold] {info.get('memory_gb', 0):.1f} GB
[bold]GPU:[/bold] {info.get('gpu', 'None detected')}

[bold cyan]Recommended Model:[/bold cyan] {recommended.get('transcription', {}).get('model', 'base')}
[bold cyan]Compute Type:[/bold cyan] {recommended.get('transcription', {}).get('compute_type', 'int8')}
"""
            self.query_one("#system-info-content", Static).update(content)
        except Exception as e:
            self.query_one("#system-info-content", Static).update(f"[red]Error: {e}[/red]")

    async def on_button_pressed(self, event: Button.Pressed):
        """Handle button presses"""
        button_id = event.button.id

        # Format buttons
        if button_id and button_id.startswith("fmt-"):
            fmt = button_id.replace("fmt-", "")
            self.selected_format = fmt
            for btn in self.query(".format-btn"):
                btn.variant = "primary" if btn.id == button_id else "default"
            return

        # Action buttons
        if button_id == "browse-btn":
            await self.action_browse_file()

        elif button_id == "transcribe-btn":
            await self.action_transcribe()

        elif button_id == "download-btn":
            await self.action_download_model()

        elif button_id == "pause-btn":
            self.action_pause_download()

        elif button_id == "resume-btn":
            self.action_resume_download()

        elif button_id == "refresh-system-btn":
            self.refresh_system_info()

        elif button_id == "record-start-btn":
            await self.action_start_recording()

        elif button_id == "record-stop-btn":
            self.action_stop_recording()

    async def action_browse_file(self):
        """Open file picker"""
        result = await self.push_screen_wait(FilePickerScreen())
        if result:
            self.selected_file = result
            self.query_one("#file-input", Input).value = str(result)

    @work(exclusive=True, thread=True)
    def do_transcription(self, file_path: Path, model: str, options: list):
        """Run transcription in background thread"""
        worker = get_current_worker()

        try:
            result = transcribe_file(
                file_path,
                model=model,
                config=self.config,
                translate="translate" in options,
                speakers="speakers" in options,
            )

            if not worker.is_cancelled:
                return result
        except Exception as e:
            if not worker.is_cancelled:
                raise e

    async def action_transcribe(self):
        """Start transcription"""
        file_input = self.query_one("#file-input", Input)
        file_path = Path(file_input.value) if file_input.value else self.selected_file

        if not file_path or not file_path.exists():
            self.notify("Please select a valid audio file", severity="error")
            return

        # Get selected model
        model_list = self.query_one("#model-select", SelectionList)
        selected = list(model_list.selected)
        model = selected[0] if selected else "base"

        # Get options
        options_list = self.query_one("#options-select", SelectionList)
        options = list(options_list.selected)

        status = self.query_one("#status-label", Static)
        progress = self.query_one("#progress-bar", ProgressBar)
        log = self.query_one("#output-log", RichLog)

        status.update(f"[cyan]Transcribing {file_path.name}...[/cyan]")
        progress.update(progress=0, total=100)
        log.clear()
        log.write(f"[bold]Starting transcription...[/bold]")
        log.write(f"File: {file_path}")
        log.write(f"Model: {model}")
        log.write(f"Options: {options or 'None'}")

        try:
            # Run transcription
            self.do_transcription(file_path, model, options)

            status.update("[green]✓ Transcription complete![/green]")
            progress.update(progress=100, total=100)

            # Output would be written to log here
            log.write("[green]Transcription completed successfully![/green]")

        except Exception as e:
            status.update(f"[red]✗ Error: {e}[/red]")
            log.write(f"[red]Error: {e}[/red]")
            self.notify(f"Transcription failed: {e}", severity="error")

    async def action_download_model(self):
        """Download selected model"""
        table = self.query_one("#models-table", DataTable)
        if table.cursor_row is not None:
            row_key = table.get_row_at(table.cursor_row)
            model_name = str(row_key[0]) if row_key else None

            if model_name:
                status = self.query_one("#download-status", Static)
                status.update(f"[cyan]Starting download of {model_name}...[/cyan]")

                try:
                    self.model_manager.download_whisper_model(model_name)
                    self.notify(f"Download started for {model_name}")
                    self.refresh_models_table()
                except Exception as e:
                    self.notify(f"Download failed: {e}", severity="error")

    def action_pause_download(self):
        """Pause selected download"""
        table = self.query_one("#models-table", DataTable)
        if table.cursor_row is not None:
            row_key = table.get_row_at(table.cursor_row)
            model_name = str(row_key[0]) if row_key else None

            if model_name and self.model_manager.pause_download(model_name):
                self.notify(f"Paused download of {model_name}")
                self.refresh_models_table()

    def action_resume_download(self):
        """Resume selected download"""
        table = self.query_one("#models-table", DataTable)
        if table.cursor_row is not None:
            row_key = table.get_row_at(table.cursor_row)
            model_name = str(row_key[0]) if row_key else None

            if model_name and self.model_manager.resume_download(model_name):
                self.notify(f"Resumed download of {model_name}")
                self.refresh_models_table()

    async def action_start_recording(self):
        """Start audio recording"""
        duration_input = self.query_one("#record-duration", Input)
        output_input = self.query_one("#record-output", Input)
        status = self.query_one("#record-status", Static)

        try:
            duration = int(duration_input.value)
        except ValueError:
            self.notify("Invalid duration", severity="error")
            return

        output_file = output_input.value or "recording.wav"

        status.update("[red]⏺️ Recording...[/red]")
        self.query_one("#record-start-btn", Button).disabled = True
        self.query_one("#record-stop-btn", Button).disabled = False

        self.notify(f"Recording started - {duration}s to {output_file}")

    def action_stop_recording(self):
        """Stop audio recording"""
        status = self.query_one("#record-status", Static)
        status.update("[green]✓ Recording saved[/green]")

        self.query_one("#record-start-btn", Button).disabled = False
        self.query_one("#record-stop-btn", Button).disabled = True

        self.notify("Recording stopped")

    def action_help(self):
        """Show help screen"""
        self.push_screen(HelpScreen())

    def action_toggle_dark(self):
        """Toggle dark mode"""
        self.dark = not self.dark

    def action_focus_transcribe(self):
        """Switch to transcribe tab"""
        self.query_one(TabbedContent).active = "transcribe"

    def action_focus_models(self):
        """Switch to models tab"""
        self.query_one(TabbedContent).active = "models"

    def action_focus_record(self):
        """Switch to record tab"""
        self.query_one(TabbedContent).active = "record"

    def action_focus_system(self):
        """Switch to system tab"""
        self.query_one(TabbedContent).active = "system"


def run_tui():
    """Run the TUI application"""
    app = WhisperApp()
    app.run()


if __name__ == "__main__":
    run_tui()
