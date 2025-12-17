import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transcript_segment.dart';

/// Audio recording service
/// Combines functionality from AudioRecorder.swift (macOS) and AudioRecorder.cs (Windows)
class AudioRecorderService extends ChangeNotifier {
  final Record _recorder = Record();
  
  bool _isRecording = false;
  bool _isPaused = false;
  double _duration = 0.0;
  double _audioLevel = 0.0;
  String? _currentRecordingPath;
  final List<TranscriptSegment> _segments = [];
  String _transcriptionText = '';
  Timer? _durationTimer;
  Timer? _amplitudeTimer;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  double get duration => _duration;
  double get audioLevel => _audioLevel;
  List<TranscriptSegment> get segments => _segments;
  String get transcriptionText => _transcriptionText;
  bool get hasPermission => _hasPermission;
  
  bool _hasPermission = false;

  AudioRecorderService() {
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    _hasPermission = status.isGranted;
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    _hasPermission = status.isGranted;
    notifyListeners();
    return _hasPermission;
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Microphone permission not granted');
      }
    }

    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/recording_$timestamp.m4a';

      // Start recording with v6.1.2 API using RecordConfig
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _isPaused = false;
      _duration = 0.0;
      
      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _duration += 0.1;
        notifyListeners();
      });

      // Start amplitude monitoring
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        final amplitude = await _recorder.getAmplitude();
        _audioLevel = amplitude.current / amplitude.max;
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      rethrow;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();
      
      _isRecording = false;
      _isPaused = false;
      _durationTimer?.cancel();
      _amplitudeTimer?.cancel();
      _audioLevel = 0.0;

      notifyListeners();

      // Note: In a real implementation, this would trigger transcription
      // For now, we'll add a placeholder segment
      if (path != null && _duration > 0) {
        _addMockTranscription();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    try {
      await _recorder.pause();
      _isPaused = true;
      _durationTimer?.cancel();
      _amplitudeTimer?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _recorder.resume();
      _isPaused = false;
      
      // Restart timers
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _duration += 0.1;
        notifyListeners();
      });

      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        final amplitude = await _recorder.getAmplitude();
        _audioLevel = amplitude.current / amplitude.max;
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  /// TODO: Replace with actual Whisper transcription implementation
  /// This is a placeholder method that creates mock transcription segments
  /// for demonstration purposes.
  /// 
  /// Real implementation should:
  /// 1. Load Whisper model (using whisper_flutter or similar package)
  /// 2. Process the recorded audio file
  /// 3. Generate actual transcript segments with accurate timestamps
  /// 4. Support multiple languages and model sizes (tiny, base, small, etc.)
  /// 
  /// See macOS implementation: mac/Sources/Talkies/TranscriptionService.swift
  /// See Windows implementation: windows/Talkies.Windows/Services/WhisperNetTranscriptionService.cs
  void _addMockTranscription() {
    // PLACEHOLDER: Mock transcription for demonstration
    // This will be replaced with actual Whisper integration
    final segment = TranscriptSegment(
      text: 'Transcription will appear here after implementing Whisper integration',
      start: 0.0,
      end: _duration,
      timestamp: TranscriptSegment.formatTimestamp(0.0),
    );
    
    _segments.add(segment);
    _transcriptionText = _segments.map((s) => s.text).join(' ');
    notifyListeners();
  }

  void addSegment(TranscriptSegment segment) {
    _segments.add(segment);
    _transcriptionText = _segments.map((s) => s.text).join(' ');
    notifyListeners();
  }

  void clearTranscription() {
    _segments.clear();
    _transcriptionText = '';
    notifyListeners();
  }

  String? getCurrentRecordingPath() {
    return _currentRecordingPath;
  }

  // Statistics
  int get totalWords {
    return _transcriptionText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get segmentCount => _segments.length;

  int get wordsPerMinute {
    if (_duration <= 0) return 0;
    return (totalWords / (_duration / 60.0)).round();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
