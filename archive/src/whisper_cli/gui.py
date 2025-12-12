"""
Native desktop GUI for real-time VTT streaming using PyQt6.
Professional, extensive interface inspired by WhisperFlow.
"""

import sys
import time
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QTextEdit, QLabel, QFileDialog, QMessageBox,
    QFrame, QScrollArea, QSizePolicy, QComboBox, QCheckBox,
    QGroupBox, QTabWidget, QLineEdit, QSpinBox
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread, QPropertyAnimation, QEasingCurve, QRect
from PyQt6.QtGui import QFont, QColor, QPalette, QLinearGradient, QPainter, QBrush

from .realtime import RealtimeVTTStream, VTTSegment


class TranscriptionThread(QThread):
    """Background thread for running transcription."""
    segment_ready = pyqtSignal(dict)
    error_occurred = pyqtSignal(str)
    backend_ready = pyqtSignal(str)

    def __init__(self, model: str, language: Optional[str], config: Dict[str, Any], use_mlx: bool):
        super().__init__()
        self.model = model
        self.language = language
        self.config = config
        self.use_mlx = use_mlx
        self.streamer = None
        self.is_running = False

    def run(self):
        """Start transcription stream."""
        try:
            self.streamer = RealtimeVTTStream(
                model=self.model,
                language=self.language,
                use_mlx=self.use_mlx,
                vad_enabled=True,
                config=self.config
            )

            # Emit backend info
            backend = "MLX (GPU)" if self.streamer.backend == "mlx" else "CPU"
            self.backend_ready.emit(backend)

            def on_segment(segment: VTTSegment):
                self.segment_ready.emit({
                    'timestamp': segment._format_timestamp(segment.start),
                    'text': segment.text,
                    'start': segment.start,
                    'end': segment.end
                })

            self.streamer.on_segment(on_segment)
            self.streamer.start()
            self.is_running = True

            # Keep thread alive while recording
            while self.is_running:
                self.msleep(100)

        except Exception as e:
            self.error_occurred.emit(str(e))

    def stop(self):
        """Stop transcription stream."""
        self.is_running = False
        if self.streamer:
            self.streamer.stop()

    def get_vtt(self) -> str:
        """Get VTT content."""
        if self.streamer:
            return self.streamer.get_vtt()
        return "WEBVTT\n\n"


class SegmentWidget(QFrame):
    """Custom widget for displaying a single transcript segment."""

    def __init__(self, timestamp: str, text: str, parent=None):
        super().__init__(parent)
        self.setFrameStyle(QFrame.Shape.StyledPanel)
        self.setStyleSheet("""
            SegmentWidget {
                background-color: #252525;
                border-left: 4px solid #667eea;
                border-radius: 8px;
                padding: 12px;
                margin: 8px 0;
            }
            SegmentWidget:hover {
                background-color: #2a2a2a;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setSpacing(5)
        layout.setContentsMargins(12, 12, 12, 12)

        # Timestamp label
        timestamp_label = QLabel(timestamp)
        timestamp_label.setFont(QFont("Monaco", 10, QFont.Weight.Bold))
        timestamp_label.setStyleSheet("color: #667eea;")
        layout.addWidget(timestamp_label)

        # Text label
        text_label = QLabel(text)
        text_label.setFont(QFont("SF Pro", 13))
        text_label.setWordWrap(True)
        text_label.setStyleSheet("color: #e0e0e0;")
        layout.addWidget(text_label)

        # Animation for entrance
        self.setMaximumHeight(0)
        self.animation = QPropertyAnimation(self, b"maximumHeight")
        self.animation.setDuration(300)
        self.animation.setStartValue(0)
        self.animation.setEndValue(100)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.animation.start()


class TalkiesGUI(QMainWindow):
    """Main GUI window for Talkies real-time transcription."""

    def __init__(self, model: str = "medium", language: Optional[str] = None,
                 config: Optional[Dict[str, Any]] = None, use_mlx: bool = True):
        super().__init__()

        self.model = model
        self.language = language
        self.config = config or {}
        self.use_mlx = use_mlx

        self.transcription_thread = None
        self.is_recording = False
        self.start_time = None
        self.segments: List[Dict] = []
        self.total_words = 0
        self.words_per_minute = 0

        self.init_ui()
        self.setup_timer()
        self.apply_modern_theme()

    def init_ui(self):
        """Initialize the user interface."""
        self.setWindowTitle("Talkies - Real-Time VTT Transcription")
        self.setGeometry(100, 100, 1200, 800)
        self.setMinimumSize(1000, 700)

        # Central widget with main layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QHBoxLayout(central_widget)
        main_layout.setSpacing(0)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # Left sidebar for controls and settings
        self.create_sidebar(main_layout)

        # Right panel for transcript display
        self.create_transcript_panel(main_layout)

    def create_sidebar(self, parent_layout):
        """Create left sidebar with controls."""
        sidebar = QFrame()
        sidebar.setFixedWidth(380)
        sidebar.setStyleSheet("""
            QFrame {
                background: qlineargradient(
                    x1:0, y1:0, x2:0, y2:1,
                    stop:0 #667eea,
                    stop:1 #764ba2
                );
            }
        """)

        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setSpacing(20)
        sidebar_layout.setContentsMargins(25, 30, 25, 30)

        # Logo and title
        title_label = QLabel("🎤 Talkies")
        title_label.setFont(QFont("SF Pro Display", 36, QFont.Weight.Bold))
        title_label.setStyleSheet("color: white;")
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(title_label)

        subtitle_label = QLabel("Real-Time Transcription")
        subtitle_label.setFont(QFont("SF Pro", 14))
        subtitle_label.setStyleSheet("color: rgba(255,255,255,0.9);")
        subtitle_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(subtitle_label)

        sidebar_layout.addSpacing(20)

        # Status indicators
        status_group = self.create_status_group()
        sidebar_layout.addWidget(status_group)

        sidebar_layout.addSpacing(10)

        # Control buttons
        self.create_control_buttons(sidebar_layout)

        sidebar_layout.addSpacing(20)

        # Settings panel
        settings_group = self.create_settings_group()
        sidebar_layout.addWidget(settings_group)

        # Statistics panel
        stats_group = self.create_stats_group()
        sidebar_layout.addWidget(stats_group)

        sidebar_layout.addStretch()

        # Footer
        footer_label = QLabel("Optimized for Apple Silicon M4")
        footer_label.setFont(QFont("SF Pro", 10))
        footer_label.setStyleSheet("color: rgba(255,255,255,0.7);")
        footer_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(footer_label)

        parent_layout.addWidget(sidebar)

    def create_status_group(self):
        """Create status indicators group."""
        group = QGroupBox()
        group.setStyleSheet("""
            QGroupBox {
                background-color: rgba(255,255,255,0.1);
                border-radius: 12px;
                padding: 15px;
            }
        """)

        layout = QVBoxLayout(group)
        layout.setSpacing(12)

        # Recording status
        status_layout = QHBoxLayout()
        self.status_indicator = QLabel("⏹")
        self.status_indicator.setFont(QFont("SF Pro", 24))
        status_layout.addWidget(self.status_indicator)

        self.status_label = QLabel("Ready")
        self.status_label.setFont(QFont("SF Pro", 16, QFont.Weight.Bold))
        self.status_label.setStyleSheet("color: white;")
        status_layout.addWidget(self.status_label)
        status_layout.addStretch()
        layout.addLayout(status_layout)

        # Timer
        timer_layout = QHBoxLayout()
        timer_icon = QLabel("⏱")
        timer_icon.setFont(QFont("SF Pro", 18))
        timer_icon.setStyleSheet("color: white;")
        timer_layout.addWidget(timer_icon)

        self.timer_label = QLabel("00:00")
        self.timer_label.setFont(QFont("SF Mono", 24, QFont.Weight.Bold))
        self.timer_label.setStyleSheet("color: white;")
        timer_layout.addWidget(self.timer_label)
        timer_layout.addStretch()
        layout.addLayout(timer_layout)

        # Backend info
        backend_layout = QHBoxLayout()
        backend_icon = QLabel("⚡")
        backend_icon.setFont(QFont("SF Pro", 18))
        backend_icon.setStyleSheet("color: white;")
        backend_layout.addWidget(backend_icon)

        backend_name = "MLX (GPU)" if self.use_mlx else "CPU"
        self.backend_label = QLabel(backend_name)
        self.backend_label.setFont(QFont("SF Pro", 13))
        self.backend_label.setStyleSheet("color: rgba(255,255,255,0.9);")
        backend_layout.addWidget(self.backend_label)
        backend_layout.addStretch()
        layout.addLayout(backend_layout)

        return group

    def create_control_buttons(self, parent_layout):
        """Create main control buttons."""
        # Record button
        self.record_btn = QPushButton("Start Recording")
        self.record_btn.setFont(QFont("SF Pro", 16, QFont.Weight.Bold))
        self.record_btn.setMinimumHeight(60)
        self.record_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.record_btn.setStyleSheet("""
            QPushButton {
                background-color: #ff3b30;
                color: white;
                border: none;
                border-radius: 12px;
                padding: 15px;
            }
            QPushButton:hover {
                background-color: #ff2d21;
            }
            QPushButton:pressed {
                background-color: #d62518;
            }
        """)
        self.record_btn.clicked.connect(self.toggle_recording)
        parent_layout.addWidget(self.record_btn)

        # Action buttons row
        action_layout = QHBoxLayout()
        action_layout.setSpacing(10)

        self.save_btn = QPushButton("💾 Save")
        self.save_btn.setFont(QFont("SF Pro", 14, QFont.Weight.Medium))
        self.save_btn.setMinimumHeight(50)
        self.save_btn.setEnabled(False)
        self.save_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.save_btn.setStyleSheet("""
            QPushButton {
                background-color: rgba(255,255,255,0.2);
                color: white;
                border: 2px solid rgba(255,255,255,0.3);
                border-radius: 10px;
            }
            QPushButton:hover:enabled {
                background-color: rgba(255,255,255,0.3);
            }
            QPushButton:disabled {
                opacity: 0.5;
            }
        """)
        self.save_btn.clicked.connect(self.save_vtt)
        action_layout.addWidget(self.save_btn)

        self.clear_btn = QPushButton("🗑 Clear")
        self.clear_btn.setFont(QFont("SF Pro", 14, QFont.Weight.Medium))
        self.clear_btn.setMinimumHeight(50)
        self.clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.clear_btn.setStyleSheet("""
            QPushButton {
                background-color: rgba(255,255,255,0.2);
                color: white;
                border: 2px solid rgba(255,255,255,0.3);
                border-radius: 10px;
            }
            QPushButton:hover {
                background-color: rgba(255,255,255,0.3);
            }
        """)
        self.clear_btn.clicked.connect(self.clear_transcript)
        action_layout.addWidget(self.clear_btn)

        parent_layout.addLayout(action_layout)

    def create_settings_group(self):
        """Create settings panel."""
        group = QGroupBox("Settings")
        group.setFont(QFont("SF Pro", 14, QFont.Weight.Bold))
        group.setStyleSheet("""
            QGroupBox {
                color: white;
                background-color: rgba(255,255,255,0.1);
                border-radius: 12px;
                padding: 15px;
                margin-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px;
            }
            QLabel {
                color: rgba(255,255,255,0.9);
            }
            QComboBox, QSpinBox, QLineEdit {
                background-color: rgba(255,255,255,0.2);
                color: white;
                border: 1px solid rgba(255,255,255,0.3);
                border-radius: 6px;
                padding: 8px;
                font-size: 13px;
            }
            QComboBox::drop-down {
                border: none;
            }
            QComboBox::down-arrow {
                image: none;
                border: none;
            }
            QCheckBox {
                color: rgba(255,255,255,0.9);
                spacing: 8px;
            }
            QCheckBox::indicator {
                width: 20px;
                height: 20px;
                border-radius: 4px;
                border: 2px solid rgba(255,255,255,0.5);
                background-color: rgba(255,255,255,0.1);
            }
            QCheckBox::indicator:checked {
                background-color: #4cd964;
                border-color: #4cd964;
            }
        """)

        layout = QVBoxLayout(group)
        layout.setSpacing(12)

        # Model selection
        model_label = QLabel("Model:")
        model_label.setFont(QFont("SF Pro", 12, QFont.Weight.Medium))
        layout.addWidget(model_label)

        self.model_combo = QComboBox()
        self.model_combo.addItems(["tiny", "base", "small", "medium", "large", "large-v3-turbo"])
        self.model_combo.setCurrentText(self.model)
        self.model_combo.setFont(QFont("SF Pro", 12))
        layout.addWidget(self.model_combo)

        # Language selection
        language_label = QLabel("Language:")
        language_label.setFont(QFont("SF Pro", 12, QFont.Weight.Medium))
        layout.addWidget(language_label)

        self.language_combo = QComboBox()
        self.language_combo.addItems([
            "auto", "en", "es", "fr", "de", "it", "pt", "ru", "ja", "zh", "ko", "ar", "hi"
        ])
        if self.language:
            self.language_combo.setCurrentText(self.language)
        self.language_combo.setFont(QFont("SF Pro", 12))
        layout.addWidget(self.language_combo)

        # VAD toggle
        self.vad_checkbox = QCheckBox("Voice Activity Detection")
        self.vad_checkbox.setChecked(True)
        self.vad_checkbox.setFont(QFont("SF Pro", 12))
        layout.addWidget(self.vad_checkbox)

        # Hallucination filter toggle
        self.filter_checkbox = QCheckBox("Hallucination Filter")
        self.filter_checkbox.setChecked(True)
        self.filter_checkbox.setFont(QFont("SF Pro", 12))
        layout.addWidget(self.filter_checkbox)

        return group

    def create_stats_group(self):
        """Create statistics panel."""
        group = QGroupBox("Statistics")
        group.setFont(QFont("SF Pro", 14, QFont.Weight.Bold))
        group.setStyleSheet("""
            QGroupBox {
                color: white;
                background-color: rgba(255,255,255,0.1);
                border-radius: 12px;
                padding: 15px;
                margin-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px;
            }
        """)

        layout = QVBoxLayout(group)
        layout.setSpacing(10)

        # Segments count
        segments_layout = QHBoxLayout()
        segments_icon = QLabel("📊")
        segments_icon.setFont(QFont("SF Pro", 16))
        segments_layout.addWidget(segments_icon)

        self.segment_count_label = QLabel("Segments: 0")
        self.segment_count_label.setFont(QFont("SF Pro", 13))
        self.segment_count_label.setStyleSheet("color: rgba(255,255,255,0.9);")
        segments_layout.addWidget(self.segment_count_label)
        segments_layout.addStretch()
        layout.addLayout(segments_layout)

        # Word count
        words_layout = QHBoxLayout()
        words_icon = QLabel("📝")
        words_icon.setFont(QFont("SF Pro", 16))
        words_layout.addWidget(words_icon)

        self.words_label = QLabel("Words: 0")
        self.words_label.setFont(QFont("SF Pro", 13))
        self.words_label.setStyleSheet("color: rgba(255,255,255,0.9);")
        words_layout.addWidget(self.words_label)
        words_layout.addStretch()
        layout.addLayout(words_layout)

        # WPM
        wpm_layout = QHBoxLayout()
        wpm_icon = QLabel("⚡")
        wpm_icon.setFont(QFont("SF Pro", 16))
        wpm_layout.addWidget(wpm_icon)

        self.wpm_label = QLabel("WPM: 0")
        self.wpm_label.setFont(QFont("SF Pro", 13))
        self.wpm_label.setStyleSheet("color: rgba(255,255,255,0.9);")
        wpm_layout.addWidget(self.wpm_label)
        wpm_layout.addStretch()
        layout.addLayout(wpm_layout)

        return group

    def create_transcript_panel(self, parent_layout):
        """Create right panel for transcript display."""
        panel = QFrame()
        panel.setStyleSheet("""
            QFrame {
                background-color: #1a1a1a;
            }
        """)

        layout = QVBoxLayout(panel)
        layout.setSpacing(0)
        layout.setContentsMargins(0, 0, 0, 0)

        # Header
        header = QFrame()
        header.setFixedHeight(70)
        header.setStyleSheet("""
            QFrame {
                background-color: #252525;
                border-bottom: 1px solid #333;
            }
        """)

        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(30, 0, 30, 0)

        header_title = QLabel("Live Transcript")
        header_title.setFont(QFont("SF Pro Display", 24, QFont.Weight.Bold))
        header_title.setStyleSheet("color: #ffffff;")
        header_layout.addWidget(header_title)

        header_layout.addStretch()

        # Export button in header
        export_btn = QPushButton("📤 Export")
        export_btn.setFont(QFont("SF Pro", 13, QFont.Weight.Medium))
        export_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        export_btn.setStyleSheet("""
            QPushButton {
                background-color: #667eea;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 10px 20px;
            }
            QPushButton:hover {
                background-color: #5568d3;
            }
        """)
        export_btn.clicked.connect(self.save_vtt)
        header_layout.addWidget(export_btn)

        layout.addWidget(header)

        # Scroll area for segments
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setStyleSheet("""
            QScrollArea {
                border: none;
                background-color: #1a1a1a;
            }
            QScrollBar:vertical {
                background-color: #1a1a1a;
                width: 10px;
                border-radius: 5px;
            }
            QScrollBar::handle:vertical {
                background-color: #444;
                border-radius: 5px;
                min-height: 20px;
            }
            QScrollBar::handle:vertical:hover {
                background-color: #555;
            }
        """)

        # Container for segments
        self.segments_container = QWidget()
        self.segments_layout = QVBoxLayout(self.segments_container)
        self.segments_layout.setSpacing(0)
        self.segments_layout.setContentsMargins(30, 20, 30, 20)
        self.segments_layout.addStretch()

        scroll_area.setWidget(self.segments_container)
        layout.addWidget(scroll_area)

        # Empty state
        self.empty_state = QLabel(
            "🎙️\n\n"
            "Click 'Start Recording' and begin speaking\n\n"
            "Your transcription will appear here in real-time"
        )
        self.empty_state.setFont(QFont("SF Pro", 16))
        self.empty_state.setStyleSheet("color: #666;")
        self.empty_state.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.segments_layout.insertWidget(0, self.empty_state)

        parent_layout.addWidget(panel)

    def apply_modern_theme(self):
        """Apply modern dark theme."""
        palette = QPalette()
        palette.setColor(QPalette.ColorRole.Window, QColor(26, 26, 26))
        palette.setColor(QPalette.ColorRole.WindowText, QColor(255, 255, 255))
        self.setPalette(palette)

    def setup_timer(self):
        """Setup timer for updating elapsed time."""
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_timer)

    def toggle_recording(self):
        """Start or stop recording."""
        if not self.is_recording:
            self.start_recording()
        else:
            self.stop_recording()

    def start_recording(self):
        """Start real-time transcription."""
        self.is_recording = True
        self.start_time = time.time()
        self.segments = []
        self.total_words = 0

        # Update UI
        self.status_indicator.setText("⏺")
        self.status_label.setText("Recording")
        self.status_label.setStyleSheet("color: #ff3b30;")

        self.record_btn.setText("Stop Recording")
        self.record_btn.setStyleSheet("""
            QPushButton {
                background-color: #8e8e93;
                color: white;
                border: none;
                border-radius: 12px;
                padding: 15px;
            }
            QPushButton:hover {
                background-color: #636366;
            }
        """)
        self.save_btn.setEnabled(False)

        # Get current settings
        model = self.model_combo.currentText()
        language = self.language_combo.currentText()
        if language == "auto":
            language = None

        # Start transcription thread
        self.transcription_thread = TranscriptionThread(
            model, language, self.config, self.use_mlx
        )
        self.transcription_thread.segment_ready.connect(self.on_new_segment)
        self.transcription_thread.error_occurred.connect(self.on_error)
        self.transcription_thread.backend_ready.connect(self.on_backend_ready)
        self.transcription_thread.start()

        # Start timer
        self.timer.start(1000)

    def stop_recording(self):
        """Stop real-time transcription."""
        self.is_recording = False

        # Stop transcription thread
        if self.transcription_thread:
            self.transcription_thread.stop()
            self.transcription_thread.wait()

        # Update UI
        self.status_indicator.setText("⏹")
        self.status_label.setText("Stopped")
        self.status_label.setStyleSheet("color: white;")

        self.record_btn.setText("Start Recording")
        self.record_btn.setStyleSheet("""
            QPushButton {
                background-color: #ff3b30;
                color: white;
                border: none;
                border-radius: 12px;
                padding: 15px;
            }
            QPushButton:hover {
                background-color: #ff2d21;
            }
        """)
        self.save_btn.setEnabled(True)

        # Stop timer
        self.timer.stop()

    def update_timer(self):
        """Update elapsed time and stats."""
        if self.start_time:
            elapsed = int(time.time() - self.start_time)
            minutes = elapsed // 60
            seconds = elapsed % 60
            self.timer_label.setText(f"{minutes:02d}:{seconds:02d}")

            # Update WPM
            if elapsed > 0:
                self.words_per_minute = int((self.total_words / elapsed) * 60)
                self.wpm_label.setText(f"WPM: {self.words_per_minute}")

    def on_backend_ready(self, backend: str):
        """Update backend label when ready."""
        self.backend_label.setText(backend)

    def on_new_segment(self, segment_data: dict):
        """Handle new transcription segment."""
        self.segments.append(segment_data)

        # Remove empty state if present
        if self.empty_state.parent():
            self.empty_state.setParent(None)

        # Add segment widget
        segment_widget = SegmentWidget(
            segment_data['timestamp'],
            segment_data['text']
        )

        # Insert before stretch
        self.segments_layout.insertWidget(
            self.segments_layout.count() - 1,
            segment_widget
        )

        # Update statistics
        words = len(segment_data['text'].split())
        self.total_words += words

        self.segment_count_label.setText(f"Segments: {len(self.segments)}")
        self.words_label.setText(f"Words: {self.total_words}")

        # Auto-scroll to bottom
        QTimer.singleShot(100, self.scroll_to_bottom)

    def scroll_to_bottom(self):
        """Scroll transcript to bottom."""
        scroll_area = self.segments_container.parent()
        if isinstance(scroll_area, QScrollArea):
            scrollbar = scroll_area.verticalScrollBar()
            scrollbar.setValue(scrollbar.maximum())

    def on_error(self, error_msg: str):
        """Handle transcription error."""
        QMessageBox.critical(self, "Error", f"Transcription error: {error_msg}")
        self.stop_recording()

    def save_vtt(self):
        """Save VTT file."""
        if not self.transcription_thread or not self.segments:
            QMessageBox.warning(self, "No Content", "No transcription to save.")
            return

        # Get save path
        default_filename = f"talkies_{datetime.now().strftime('%Y%m%d_%H%M%S')}.vtt"
        file_path, _ = QFileDialog.getSaveFileName(
            self,
            "Save VTT File",
            default_filename,
            "VTT Files (*.vtt);;All Files (*)"
        )

        if file_path:
            try:
                vtt_content = self.transcription_thread.get_vtt()
                Path(file_path).write_text(vtt_content, encoding='utf-8')
                QMessageBox.information(
                    self,
                    "Success",
                    f"VTT file saved successfully!\n\n{file_path}"
                )
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to save VTT:\n{str(e)}")

    def clear_transcript(self):
        """Clear transcript display."""
        if not self.segments:
            return

        reply = QMessageBox.question(
            self,
            "Clear Transcript",
            "Are you sure you want to clear all transcription text?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            # Clear segments
            while self.segments_layout.count() > 1:  # Keep stretch item
                item = self.segments_layout.takeAt(0)
                if item.widget():
                    item.widget().deleteLater()

            self.segments = []
            self.total_words = 0
            self.words_per_minute = 0

            # Reset statistics
            self.segment_count_label.setText("Segments: 0")
            self.words_label.setText("Words: 0")
            self.wpm_label.setText("WPM: 0")

            # Show empty state
            self.segments_layout.insertWidget(0, self.empty_state)

    def closeEvent(self, event):
        """Handle window close event."""
        if self.is_recording:
            reply = QMessageBox.question(
                self,
                "Recording in Progress",
                "Recording is in progress. Stop and exit?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No
            )

            if reply == QMessageBox.StandardButton.Yes:
                self.stop_recording()
                event.accept()
            else:
                event.ignore()
        else:
            event.accept()


def launch_gui(
    model: str = "medium",
    language: Optional[str] = None,
    config: Optional[Dict[str, Any]] = None,
    use_mlx: bool = True
):
    """
    Launch native desktop GUI.

    Args:
        model: Whisper model size
        language: Language code
        config: Configuration dictionary
        use_mlx: Use MLX (GPU) or faster-whisper (CPU)
    """
    app = QApplication(sys.argv)

    # Set application style for macOS
    app.setStyle("Fusion")

    # Set high DPI support
    app.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )

    # Create and show window
    window = TalkiesGUI(model=model, language=language, config=config, use_mlx=use_mlx)
    window.show()

    sys.exit(app.exec())
