import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_recorder_service.dart';

/// Visual indicator for audio input level
/// Based on WaveformVisualizer from Windows implementation
class AudioLevelIndicator extends StatelessWidget {
  const AudioLevelIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioRecorderService>();
    final level = audioService.audioLevel.clamp(0.0, 1.0);

    return Column(
      children: [
        Text(
          'Audio Level',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: level,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getLevelColor(context, level),
              ),
              minHeight: 40,
            ),
          ),
        ),
      ],
    );
  }

  Color _getLevelColor(BuildContext context, double level) {
    if (level < 0.3) {
      return Colors.green;
    } else if (level < 0.7) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }
}
