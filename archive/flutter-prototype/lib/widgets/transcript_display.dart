import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_recorder_service.dart';

/// Display for transcription segments
/// Based on TranscriptView.swift and transcript display in Windows
class TranscriptDisplay extends StatelessWidget {
  const TranscriptDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioRecorderService>();

    if (audioService.segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Start recording to see transcription',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: audioService.segments.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final segment = audioService.segments[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(segment.text),
            subtitle: Text(
              segment.timestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          );
        },
      ),
    );
  }
}
