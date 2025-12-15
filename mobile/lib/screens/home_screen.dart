import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_recorder_service.dart';
import '../services/settings_service.dart';
import '../widgets/recording_controls.dart';
import '../widgets/transcript_display.dart';
import '../widgets/audio_level_indicator.dart';
import 'settings_screen.dart';

/// Main home screen with recording interface
/// Combines features from DictationView.swift (macOS) and MainWindow.xaml (Windows)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioRecorderService>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talkies Mobile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: audioService.segments.isEmpty
                ? null
                : () {
                    _showClearConfirmation(context);
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Audio level indicator (like waveform in Windows)
            if (audioService.isRecording)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: AudioLevelIndicator(),
              ),
            
            // Recording stats
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            label: 'Duration',
                            value: _formatDuration(audioService.duration),
                          ),
                          _StatItem(
                            label: 'Words',
                            value: '${audioService.totalWords}',
                          ),
                          _StatItem(
                            label: 'WPM',
                            value: '${audioService.wordsPerMinute}',
                          ),
                          _StatItem(
                            label: 'Segments',
                            value: '${audioService.segmentCount}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Transcript display
            const Expanded(
              child: TranscriptDisplay(),
            ),
            
            // Recording controls
            const RecordingControls(),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Transcription'),
        content: const Text('Are you sure you want to clear the current transcription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AudioRecorderService>().clearTranscription();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
