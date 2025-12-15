import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transcript_segment.dart';

/// Export service for transcripts in multiple formats
/// Based on TranscriptExporter.cs from Windows implementation
class ExportService {
  /// Export transcript as SRT (SubRip) format
  static Future<String> exportAsSrt(List<TranscriptSegment> segments) async {
    final buffer = StringBuffer();
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      buffer.writeln(i + 1);
      buffer.writeln('${_formatSrtTimestamp(segment.start)} --> ${_formatSrtTimestamp(segment.end)}');
      buffer.writeln(segment.text);
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// Export transcript as VTT (WebVTT) format
  static Future<String> exportAsVtt(List<TranscriptSegment> segments) async {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      buffer.writeln('${_formatVttTimestamp(segment.start)} --> ${_formatVttTimestamp(segment.end)}');
      buffer.writeln(segment.text);
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// Export transcript as plain text with timestamps
  static Future<String> exportAsText(List<TranscriptSegment> segments) async {
    final buffer = StringBuffer();
    
    for (final segment in segments) {
      buffer.writeln('[${segment.timestamp}] ${segment.text}');
    }
    
    return buffer.toString();
  }

  /// Save and share export file
  static Future<void> saveAndShare({
    required List<TranscriptSegment> segments,
    required String format,
  }) async {
    String content;
    String extension;
    
    switch (format.toLowerCase()) {
      case 'srt':
        content = await exportAsSrt(segments);
        extension = 'srt';
        break;
      case 'vtt':
        content = await exportAsVtt(segments);
        extension = 'vtt';
        break;
      case 'txt':
      default:
        content = await exportAsText(segments);
        extension = 'txt';
        break;
    }
    
    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/transcript_$timestamp.$extension';
    final file = File(filePath);
    await file.writeAsString(content);
    
    // Share the file
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Talkies Transcript',
      text: 'Transcript exported from Talkies Mobile',
    );
  }

  /// Format timestamp for SRT format (HH:MM:SS,mmm)
  static String _formatSrtTimestamp(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$secs,$millis';
  }

  /// Format timestamp for VTT format (HH:MM:SS.mmm)
  static String _formatVttTimestamp(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$secs.$millis';
  }
}
