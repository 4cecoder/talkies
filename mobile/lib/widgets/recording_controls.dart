import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_recorder_service.dart';
import '../services/export_service.dart';

/// Recording control buttons
/// Based on controls from DictationView.swift and MainWindow.xaml
class RecordingControls extends StatelessWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioRecorderService>();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary recording button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (audioService.isRecording && !audioService.isPaused)
                IconButton(
                  iconSize: 48,
                  onPressed: () => audioService.pauseRecording(),
                  icon: const Icon(Icons.pause_circle),
                ),
              if (audioService.isRecording && audioService.isPaused)
                IconButton(
                  iconSize: 48,
                  onPressed: () => audioService.resumeRecording(),
                  icon: const Icon(Icons.play_circle),
                ),
              const SizedBox(width: 16),
              FloatingActionButton.large(
                onPressed: () async {
                  if (audioService.isRecording) {
                    await audioService.stopRecording();
                  } else {
                    try {
                      await audioService.startRecording();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                },
                child: Icon(
                  audioService.isRecording ? Icons.stop : Icons.mic,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              if (audioService.isRecording)
                IconButton(
                  iconSize: 48,
                  onPressed: audioService.segments.isEmpty
                      ? null
                      : () => _showExportOptions(context),
                  icon: const Icon(Icons.upload_file),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Export buttons (when not recording)
          if (!audioService.isRecording && audioService.segments.isNotEmpty)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _exportAs(context, 'srt'),
                  icon: const Icon(Icons.subtitles),
                  label: const Text('Export SRT'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportAs(context, 'txt'),
                  icon: const Icon(Icons.text_snippet),
                  label: const Text('Export TXT'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportAs(context, 'vtt'),
                  icon: const Icon(Icons.closed_caption),
                  label: const Text('Export VTT'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.subtitles),
              title: const Text('Export as SRT'),
              onTap: () {
                Navigator.pop(context);
                _exportAs(context, 'srt');
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Export as TXT'),
              onTap: () {
                Navigator.pop(context);
                _exportAs(context, 'txt');
              },
            ),
            ListTile(
              leading: const Icon(Icons.closed_caption),
              title: const Text('Export as VTT'),
              onTap: () {
                Navigator.pop(context);
                _exportAs(context, 'vtt');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAs(BuildContext context, String format) async {
    final audioService = context.read<AudioRecorderService>();
    
    try {
      await ExportService.saveAndShare(
        segments: audioService.segments,
        format: format,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported as ${format.toUpperCase()}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
