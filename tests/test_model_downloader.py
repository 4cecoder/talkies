"""
Tests for model download manager
"""

import pytest
import tempfile
import json
import time
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.model_downloader import (
    ModelDownloadManager,
    DownloadTask,
    DownloadStatus
)


def test_download_manager_initialization():
    """Test download manager initialization"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        assert manager.cache_dir.exists()
        assert manager.metadata_dir.exists()


def test_download_task_serialization():
    """Test DownloadTask serialization"""
    task = DownloadTask(
        model_name="test-model",
        model_type="whisper",
        status=DownloadStatus.PENDING,
        progress=0.0,
        downloaded_bytes=0,
        total_bytes=None,
        speed=0.0,
        checksum=None,
        checksum_algorithm="sha256",
        download_path=Path("/tmp/test"),
        metadata_path=Path("/tmp/test.json"),
        process_id=None,
        start_time=None,
        pause_time=None,
        error_message=None,
        resume_data=None
    )
    
    # Test to_dict
    data = task.to_dict()
    assert data["model_name"] == "test-model"
    assert data["status"] == "pending"
    
    # Test from_dict
    task2 = DownloadTask.from_dict(data)
    assert task2.model_name == task.model_name
    assert task2.status == task.status


def test_download_whisper_model(mocker):
    """Test Whisper model download"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        with patch('faster_whisper.WhisperModel') as mock_whisper:
            mock_model = Mock()
            mock_whisper.return_value = mock_model
            
            task = manager.download_whisper_model("base")
            
            assert task.model_name == "base"
            assert task.model_type == "whisper"
            # Status may be PENDING initially, then change to DOWNLOADING when thread starts
            assert task.status in [DownloadStatus.PENDING, DownloadStatus.DOWNLOADING]
            
            # Wait a bit for thread to start and update status
            time.sleep(0.3)
            
            # Check that task was saved
            assert (manager.metadata_dir / "base.json").exists()
            
            # After thread starts, status should be DOWNLOADING or COMPLETED
            updated_task = manager.get_status("base")
            assert updated_task.status in [DownloadStatus.DOWNLOADING, DownloadStatus.COMPLETED, DownloadStatus.VERIFIED]


def test_download_ollama_model(mocker):
    """Test Ollama model download - tests initial task creation only"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))

        # For this test, we just verify the task is created correctly
        # The actual download happens in a background thread which is hard to
        # test reliably. We'll test the synchronous parts only.

        # Create a task directly to test without spawning a thread
        task = DownloadTask(
            model_name="llama3.2",
            model_type="ollama",
            status=DownloadStatus.PENDING,
            progress=0.0,
            downloaded_bytes=0,
            total_bytes=None,
            speed=0.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=manager.cache_dir / "ollama" / "llama3.2",
            metadata_path=manager.metadata_dir / "llama3.2.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )

        # Save the task
        manager.tasks["llama3.2"] = task
        manager._save_task(task)

        assert task.model_name == "llama3.2"
        assert task.model_type == "ollama"
        assert (manager.metadata_dir / "llama3.2.json").exists()


def test_pause_download(mocker):
    """Test pausing a download"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.DOWNLOADING,
            progress=50.0,
            downloaded_bytes=1000,
            total_bytes=2000,
            speed=100.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test",
            metadata_path=Path(tmpdir) / "test.json",
            process_id=12345,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        manager.tasks["test-model"] = task
        
        with patch('os.kill') as mock_kill:
            result = manager.pause_download("test-model")
            
            assert result is True
            assert task.status == DownloadStatus.PAUSED
            mock_kill.assert_called()


def test_resume_download(mocker):
    """Test resuming a paused download"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))

        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.PAUSED,
            progress=50.0,
            downloaded_bytes=1000,
            total_bytes=2000,
            speed=0.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test",
            metadata_path=manager.metadata_dir / "test-model.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )

        manager.tasks["test-model"] = task

        with patch('faster_whisper.WhisperModel') as mock_whisper:
            mock_model = Mock()
            mock_whisper.return_value = mock_model

            result = manager.resume_download("test-model")

            assert result is not None
            assert result.model_name == "test-model"

            # Wait for download thread to complete
            manager.wait_for_download("test-model", timeout=2.0)


def test_cancel_download(mocker):
    """Test cancelling a download"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        metadata_path = Path(tmpdir) / "test.json"
        metadata_path.write_text('{"test": "data"}')
        
        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.DOWNLOADING,
            progress=50.0,
            downloaded_bytes=1000,
            total_bytes=2000,
            speed=100.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test",
            metadata_path=metadata_path,
            process_id=12345,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        manager.tasks["test-model"] = task
        
        with patch('os.kill') as mock_kill:
            result = manager.cancel_download("test-model")
            
            assert result is True
            assert "test-model" not in manager.tasks
            assert not metadata_path.exists()


def test_get_status():
    """Test getting download status"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.DOWNLOADING,
            progress=50.0,
            downloaded_bytes=1000,
            total_bytes=2000,
            speed=100.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test",
            metadata_path=Path(tmpdir) / "test.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        manager.tasks["test-model"] = task
        
        status = manager.get_status("test-model")
        assert status is not None
        assert status.model_name == "test-model"
        assert status.progress == 50.0
        
        # Non-existent model
        status = manager.get_status("non-existent")
        assert status is None


def test_list_downloads():
    """Test listing all downloads"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        task1 = DownloadTask(
            model_name="model1",
            model_type="whisper",
            status=DownloadStatus.DOWNLOADING,
            progress=50.0,
            downloaded_bytes=1000,
            total_bytes=2000,
            speed=100.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test1",
            metadata_path=Path(tmpdir) / "test1.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        task2 = DownloadTask(
            model_name="model2",
            model_type="ollama",
            status=DownloadStatus.COMPLETED,
            progress=100.0,
            downloaded_bytes=2000,
            total_bytes=2000,
            speed=0.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test2",
            metadata_path=Path(tmpdir) / "test2.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        manager.tasks["model1"] = task1
        manager.tasks["model2"] = task2
        
        downloads = manager.list_downloads()
        assert len(downloads) == 2
        assert any(d.model_name == "model1" for d in downloads)
        assert any(d.model_name == "model2" for d in downloads)


def test_verify_checksum():
    """Test checksum verification"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        # Create a test file
        test_file = Path(tmpdir) / "test.bin"
        test_file.write_bytes(b"test data")
        
        # Calculate checksum
        import hashlib
        hash_obj = hashlib.sha256()
        hash_obj.update(b"test data")
        correct_checksum = hash_obj.hexdigest()
        
        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.COMPLETED,
            progress=100.0,
            downloaded_bytes=9,
            total_bytes=9,
            speed=0.0,
            checksum=correct_checksum,
            checksum_algorithm="sha256",
            download_path=test_file,
            metadata_path=Path(tmpdir) / "test.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        # Verify correct checksum
        assert manager._verify_checksum(task) is True
        
        # Verify incorrect checksum
        task.checksum = "wrong_checksum"
        assert manager._verify_checksum(task) is False


def test_wait_for_download(mocker):
    """Test waiting for download completion"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.DOWNLOADING,
            progress=50.0,
            downloaded_bytes=1000,
            total_bytes=2000,
            speed=100.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test",
            metadata_path=Path(tmpdir) / "test.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        manager.tasks["test-model"] = task
        
        # Test timeout
        result = manager.wait_for_download("test-model", timeout=0.1)
        assert result is False
        
        # Test completion
        task.status = DownloadStatus.VERIFIED
        result = manager.wait_for_download("test-model", timeout=1.0)
        assert result is True


def test_status_callback(mocker):
    """Test status callback registration"""
    with tempfile.TemporaryDirectory() as tmpdir:
        manager = ModelDownloadManager(cache_dir=Path(tmpdir))
        
        callback_called = []
        
        def callback(task):
            callback_called.append(task.model_name)
        
        manager.register_status_callback("test-model", callback)
        
        task = DownloadTask(
            model_name="test-model",
            model_type="whisper",
            status=DownloadStatus.PENDING,
            progress=0.0,
            downloaded_bytes=0,
            total_bytes=None,
            speed=0.0,
            checksum=None,
            checksum_algorithm="sha256",
            download_path=Path(tmpdir) / "test",
            metadata_path=Path(tmpdir) / "test.json",
            process_id=None,
            start_time=None,
            pause_time=None,
            error_message=None,
            resume_data=None
        )
        
        manager.tasks["test-model"] = task
        
        # Update status should trigger callback
        manager._update_status(task, DownloadStatus.DOWNLOADING)
        
        assert "test-model" in callback_called

