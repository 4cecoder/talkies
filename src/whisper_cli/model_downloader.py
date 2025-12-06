"""
Model Download Manager with subprocess support, pause/resume, and checksum verification.

Handles downloading Whisper models (via faster-whisper/huggingface) and Ollama models
with progress tracking, pause/resume capability, and checksum verification.
"""

import json
import hashlib
import subprocess
import threading
import time
import signal
import os
import logging
from pathlib import Path
from typing import Dict, Any, Optional, Callable, List
from enum import Enum
from dataclasses import dataclass, asdict
from datetime import datetime

import requests
from rich.console import Console

logger = logging.getLogger(__name__)
console = Console()


class DownloadStatus(Enum):
    """Download status enumeration"""
    PENDING = "pending"
    DOWNLOADING = "downloading"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    VERIFYING = "verifying"
    VERIFIED = "verified"


@dataclass
class DownloadTask:
    """Represents a download task"""
    model_name: str
    model_type: str  # "whisper" or "ollama"
    status: DownloadStatus
    progress: float  # 0.0 to 100.0
    downloaded_bytes: int
    total_bytes: Optional[int]
    speed: float  # bytes per second
    checksum: Optional[str]  # Expected checksum
    checksum_algorithm: str  # "sha256" or "md5"
    download_path: Path
    metadata_path: Path
    process_id: Optional[int]
    start_time: Optional[datetime]
    pause_time: Optional[datetime]
    error_message: Optional[str]
    resume_data: Optional[Dict[str, Any]]  # For resuming downloads

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = asdict(self)
        data['status'] = self.status.value
        data['download_path'] = str(self.download_path)
        data['metadata_path'] = str(self.metadata_path)
        if self.start_time:
            data['start_time'] = self.start_time.isoformat()
        if self.pause_time:
            data['pause_time'] = self.pause_time.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'DownloadTask':
        """Create from dictionary"""
        data['status'] = DownloadStatus(data['status'])
        data['download_path'] = Path(data['download_path'])
        data['metadata_path'] = Path(data['metadata_path'])
        if data.get('start_time'):
            data['start_time'] = datetime.fromisoformat(data['start_time'])
        if data.get('pause_time'):
            data['pause_time'] = datetime.fromisoformat(data['pause_time'])
        return cls(**data)


class ModelDownloadManager:
    """Manages model downloads with subprocess support, pause/resume, and checksum verification"""

    def __init__(self, cache_dir: Optional[Path] = None):
        """Initialize the download manager"""
        if cache_dir is None:
            cache_dir = Path.home() / ".cache" / "whisper-cli" / "models"
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        self.metadata_dir = self.cache_dir / "metadata"
        self.metadata_dir.mkdir(parents=True, exist_ok=True)
        
        self.tasks: Dict[str, DownloadTask] = {}
        self.lock = threading.Lock()
        self.status_callbacks: Dict[str, Callable[[DownloadTask], None]] = {}
        
        # Load existing tasks
        self._load_tasks()

    def _load_tasks(self):
        """Load existing download tasks from metadata"""
        for metadata_file in self.metadata_dir.glob("*.json"):
            try:
                with open(metadata_file, 'r') as f:
                    data = json.load(f)
                    task = DownloadTask.from_dict(data)
                    # Only load incomplete tasks
                    if task.status not in [DownloadStatus.COMPLETED, DownloadStatus.VERIFIED]:
                        self.tasks[task.model_name] = task
            except Exception as e:
                console.print(f"[yellow]Warning: Could not load task from {metadata_file}: {e}[/yellow]")

    def _save_task(self, task: DownloadTask):
        """Save task metadata to disk"""
        metadata_file = self.metadata_dir / f"{task.model_name}.json"
        with open(metadata_file, 'w') as f:
            json.dump(task.to_dict(), f, indent=2)

    def _update_status(self, task: DownloadTask, status: DownloadStatus, **kwargs):
        """Update task status and notify callbacks"""
        with self.lock:
            task.status = status
            for key, value in kwargs.items():
                if hasattr(task, key):
                    setattr(task, key, value)
            self._save_task(task)
            
            # Notify callbacks
            if task.model_name in self.status_callbacks:
                try:
                    self.status_callbacks[task.model_name](task)
                except Exception as e:
                    console.print(f"[red]Error in status callback: {e}[/red]")

    def register_status_callback(self, model_name: str, callback: Callable[[DownloadTask], None]):
        """Register a callback for status updates"""
        self.status_callbacks[model_name] = callback

    def download_whisper_model(
        self,
        model_name: str,
        checksum: Optional[str] = None,
        checksum_algorithm: str = "sha256",
        progress_callback: Optional[Callable[[float, float, float], None]] = None
    ) -> DownloadTask:
        """Download a Whisper model using faster-whisper"""
        if model_name in self.tasks:
            task = self.tasks[model_name]
            if task.status == DownloadStatus.DOWNLOADING:
                console.print(f"[yellow]Model {model_name} is already downloading[/yellow]")
                return task
            elif task.status == DownloadStatus.PAUSED:
                console.print(f"[yellow]Resuming download of {model_name}[/yellow]")
                return self.resume_download(model_name)

        # Create download task
        download_path = self.cache_dir / "whisper" / model_name
        download_path.parent.mkdir(parents=True, exist_ok=True)
        metadata_path = self.metadata_dir / f"{model_name}.json"

        task = DownloadTask(
            model_name=model_name,
            model_type="whisper",
            status=DownloadStatus.PENDING,
            progress=0.0,
            downloaded_bytes=0,
            total_bytes=None,
            speed=0.0,
            checksum=checksum,
            checksum_algorithm=checksum_algorithm,
            download_path=download_path,
            metadata_path=metadata_path,
            process_id=None,
            start_time=datetime.now(),
            pause_time=None,
            error_message=None,
            resume_data=None
        )

        self.tasks[model_name] = task
        self._save_task(task)

        # Start download in background thread
        thread = threading.Thread(
            target=self._download_whisper_model_thread,
            args=(task, progress_callback),
            daemon=True
        )
        thread.start()

        return task

    def _download_whisper_model_thread(
        self,
        task: DownloadTask,
        progress_callback: Optional[Callable[[float, float, float], None]]
    ):
        """Download Whisper model in background thread"""
        try:
            self._update_status(task, DownloadStatus.DOWNLOADING)
            
            # Use faster-whisper's model download mechanism
            # This will download via huggingface-hub
            from faster_whisper import WhisperModel
            
            console.print(f"[green]Starting download of Whisper model: {task.model_name}[/green]")
            
            # Trigger model download by initializing it
            # This is a blocking call, but we're in a thread
            model = WhisperModel(task.model_name, device="cpu", download_root=str(self.cache_dir / "whisper"))
            
            # Model is downloaded, update status
            self._update_status(task, DownloadStatus.COMPLETED, progress=100.0)
            
            # Verify checksum if provided
            if task.checksum:
                self._update_status(task, DownloadStatus.VERIFYING)
                if self._verify_checksum(task):
                    self._update_status(task, DownloadStatus.VERIFIED)
                    console.print(f"[green]Model {task.model_name} downloaded and verified[/green]")
                else:
                    self._update_status(task, DownloadStatus.FAILED, error_message="Checksum verification failed")
                    console.print(f"[red]Checksum verification failed for {task.model_name}[/red]")
            else:
                self._update_status(task, DownloadStatus.VERIFIED)
                console.print(f"[green]Model {task.model_name} downloaded successfully[/green]")
                
        except Exception as e:
            self._update_status(
                task,
                DownloadStatus.FAILED,
                error_message=str(e)
            )
            console.print(f"[red]Error downloading {task.model_name}: {e}[/red]")

    def download_ollama_model(
        self,
        model_name: str,
        ollama_url: str = "http://localhost:11434",
        progress_callback: Optional[Callable[[float, float, float], None]] = None
    ) -> DownloadTask:
        """Download an Ollama model using subprocess"""
        if model_name in self.tasks:
            task = self.tasks[model_name]
            if task.status == DownloadStatus.DOWNLOADING:
                console.print(f"[yellow]Model {model_name} is already downloading[/yellow]")
                return task
            elif task.status == DownloadStatus.PAUSED:
                console.print(f"[yellow]Resuming download of {model_name}[/yellow]")
                return self.resume_download(model_name)

        # Create download task
        download_path = self.cache_dir / "ollama" / model_name
        download_path.parent.mkdir(parents=True, exist_ok=True)
        metadata_path = self.metadata_dir / f"{model_name}.json"

        task = DownloadTask(
            model_name=model_name,
            model_type="ollama",
            status=DownloadStatus.PENDING,
            progress=0.0,
            downloaded_bytes=0,
            total_bytes=None,
            speed=0.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=download_path,
            metadata_path=metadata_path,
            process_id=None,
            start_time=datetime.now(),
            pause_time=None,
            error_message=None,
            resume_data={"ollama_url": ollama_url}  # Store for resume
        )

        self.tasks[model_name] = task
        self._save_task(task)

        # Start download in background thread
        thread = threading.Thread(
            target=self._download_ollama_model_thread,
            args=(task, ollama_url, progress_callback),
            daemon=True
        )
        thread.start()

        return task

    def _download_ollama_model_thread(
        self,
        task: DownloadTask,
        ollama_url: str,
        progress_callback: Optional[Callable[[float, float, float], None]]
    ):
        """Download Ollama model using subprocess"""
        try:
            self._update_status(task, DownloadStatus.DOWNLOADING)
            
            # Use ollama CLI via subprocess
            console.print(f"[green]Starting download of Ollama model: {task.model_name}[/green]")
            
            # Check if ollama is available
            try:
                result = subprocess.run(
                    ["ollama", "--version"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode != 0:
                    raise Exception("Ollama CLI not found or not working")
            except FileNotFoundError:
                raise Exception("Ollama CLI not found. Please install Ollama first.")
            
            # Try to use ollama's streaming API first
            import json as json_lib
            process = None
            use_api = True
            
            try:
                # Use ollama's pull API with streaming
                # Use connect timeout but no read timeout for streaming
                response = requests.post(
                    f"{ollama_url}/api/pull",
                    json={"name": task.model_name},
                    stream=True,
                    timeout=(10, None)  # 10s connect timeout, no read timeout for streaming
                )
                
                if response.status_code != 200:
                    raise Exception(f"Ollama API returned status {response.status_code}")
                
                last_update = time.time()
                total_size = 0
                
                for line in response.iter_lines():
                    if task.status == DownloadStatus.PAUSED:
                        break
                    
                    if not line:
                        continue
                    
                    try:
                        data = json_lib.loads(line)
                        
                        # Parse ollama progress
                        if "completed" in data and "total" in data:
                            completed = data.get("completed", 0)
                            total = data.get("total", 0)
                            
                            if total > 0:
                                task.total_bytes = total
                                task.downloaded_bytes = completed
                                task.progress = (completed / total) * 100.0
                                
                                # Calculate speed
                                current_time = time.time()
                                if current_time - last_update >= 1.0:
                                    elapsed = current_time - last_update
                                    bytes_delta = completed - total_size
                                    task.speed = bytes_delta / elapsed if elapsed > 0 else 0
                                    total_size = completed
                                    last_update = current_time
                                
                                if progress_callback:
                                    progress_callback(task.progress, task.downloaded_bytes, task.speed)
                                
                                self._save_task(task)
                        
                        # Check for completion
                        if data.get("status") == "success":
                            break
                        elif data.get("status") == "error":
                            raise Exception(data.get("error", "Unknown error"))
                            
                    except json_lib.JSONDecodeError:
                        continue
                        
            except (requests.exceptions.RequestException, Exception) as e:
                # Fallback to subprocess if API fails
                console.print(f"[yellow]Ollama API unavailable ({e}), using subprocess fallback[/yellow]")
                use_api = False
                
                # Start ollama pull in subprocess
                process = subprocess.Popen(
                    ["ollama", "pull", task.model_name],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1
                )
                
                task.process_id = process.pid
                self._save_task(task)
                
                last_update = time.time()
                
                # Monitor subprocess output
                for line in process.stdout:
                    if task.status == DownloadStatus.PAUSED:
                        process.terminate()
                        break
                    
                    # Simple progress estimation
                    current_time = time.time()
                    if current_time - last_update >= 1.0:
                        task.progress = min(task.progress + 2.0, 99.0)
                        if progress_callback:
                            progress_callback(task.progress, task.downloaded_bytes, task.speed)
                        self._save_task(task)
                        last_update = current_time
            
            # Wait for process to complete (only if using subprocess)
            if process:
                return_code = process.wait()
                if return_code != 0:
                    self._update_status(
                        task,
                        DownloadStatus.FAILED,
                        error_message=f"Ollama pull failed with return code {return_code}"
                    )
                    return
            
            # Verify completion
            if task.status not in [DownloadStatus.FAILED, DownloadStatus.PAUSED]:
                self._update_status(task, DownloadStatus.COMPLETED, progress=100.0)
                # Verify model is available (with small delay for model registration)
                time.sleep(1)
                self._update_status(task, DownloadStatus.VERIFYING)
                if self._verify_ollama_model(task.model_name, ollama_url):
                    self._update_status(task, DownloadStatus.VERIFIED)
                    console.print(f"[green]Ollama model {task.model_name} downloaded and verified[/green]")
                else:
                    self._update_status(task, DownloadStatus.FAILED, error_message="Model verification failed")
                
        except Exception as e:
            self._update_status(
                task,
                DownloadStatus.FAILED,
                error_message=str(e)
            )
            console.print(f"[red]Error downloading Ollama model {task.model_name}: {e}[/red]")
        finally:
            task.process_id = None
            self._save_task(task)

    def pause_download(self, model_name: str) -> bool:
        """Pause a download"""
        if model_name not in self.tasks:
            console.print(f"[red]No download task found for {model_name}[/red]")
            return False
        
        task = self.tasks[model_name]
        if task.status != DownloadStatus.DOWNLOADING:
            console.print(f"[yellow]Download {model_name} is not currently downloading[/yellow]")
            return False
        
        # Kill the process if it exists
        if task.process_id:
            try:
                os.kill(task.process_id, signal.SIGSTOP)  # Try to pause
                # If that doesn't work, terminate
                time.sleep(0.5)
                try:
                    os.kill(task.process_id, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            except ProcessLookupError:
                pass
        
        self._update_status(
            task,
            DownloadStatus.PAUSED,
            pause_time=datetime.now()
        )
        console.print(f"[yellow]Download {model_name} paused[/yellow]")
        return True

    def resume_download(self, model_name: str) -> DownloadTask:
        """Resume a paused download"""
        if model_name not in self.tasks:
            console.print(f"[red]No download task found for {model_name}[/red]")
            return None
        
        task = self.tasks[model_name]
        if task.status != DownloadStatus.PAUSED:
            console.print(f"[yellow]Download {model_name} is not paused[/yellow]")
            return task
        
        # Resume based on model type
        if task.model_type == "whisper":
            thread = threading.Thread(
                target=self._download_whisper_model_thread,
                args=(task, None),
                daemon=True
            )
            thread.start()
        elif task.model_type == "ollama":
            # Get ollama_url from task's resume_data or use default
            ollama_url = (task.resume_data or {}).get("ollama_url", "http://localhost:11434")
            thread = threading.Thread(
                target=self._download_ollama_model_thread,
                args=(task, ollama_url, None),
                daemon=True
            )
            thread.start()
        
        return task

    def cancel_download(self, model_name: str) -> bool:
        """Cancel a download"""
        if model_name not in self.tasks:
            return False
        
        task = self.tasks[model_name]
        if task.status not in [DownloadStatus.DOWNLOADING, DownloadStatus.PAUSED]:
            return False
        
        # Kill the process
        if task.process_id:
            try:
                os.kill(task.process_id, signal.SIGTERM)
            except ProcessLookupError:
                pass
        
        # Remove task
        del self.tasks[model_name]
        if task.metadata_path.exists():
            task.metadata_path.unlink()
        
        console.print(f"[yellow]Download {model_name} cancelled[/yellow]")
        return True

    def get_status(self, model_name: str) -> Optional[DownloadTask]:
        """Get download status for a model"""
        return self.tasks.get(model_name)

    def list_downloads(self) -> List[DownloadTask]:
        """List all download tasks"""
        return list(self.tasks.values())

    def _verify_checksum(self, task: DownloadTask) -> bool:
        """Verify checksum of downloaded file"""
        if not task.checksum or not task.download_path.exists():
            return False
        
        try:
            hash_obj = hashlib.sha256() if task.checksum_algorithm == "sha256" else hashlib.md5()
            with open(task.download_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_obj.update(chunk)
            
            calculated_checksum = hash_obj.hexdigest()
            return calculated_checksum.lower() == task.checksum.lower()
        except Exception as e:
            console.print(f"[red]Error verifying checksum: {e}[/red]")
            return False

    def _verify_ollama_model(self, model_name: str, ollama_url: str) -> bool:
        """Verify Ollama model is available"""
        try:
            response = requests.get(f"{ollama_url}/api/tags", timeout=5)
            if response.status_code == 200:
                data = response.json()
                models = [model['name'] for model in data.get('models', [])]
                return model_name in models
        except Exception:
            pass
        return False

    def wait_for_download(self, model_name: str, timeout: Optional[float] = None) -> bool:
        """Wait for a download to complete"""
        start_time = time.time()
        while model_name in self.tasks:
            task = self.tasks[model_name]
            if task.status in [DownloadStatus.COMPLETED, DownloadStatus.VERIFIED]:
                return True
            elif task.status == DownloadStatus.FAILED:
                return False
            
            if timeout and (time.time() - start_time) > timeout:
                return False
            
            time.sleep(0.5)
        
        return False

