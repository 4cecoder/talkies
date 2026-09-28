import 'package:json_annotation/json_annotation.dart';

part 'transcript_segment.g.dart';

/// Represents a single segment of transcribed text with timing information
/// Similar to TranscriptSegment in Windows and macOS implementations
@JsonSerializable()
class TranscriptSegment {
  final String text;
  final double start;
  final double end;
  final String timestamp;

  TranscriptSegment({
    required this.text,
    required this.start,
    required this.end,
    required this.timestamp,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSegmentFromJson(json);

  Map<String, dynamic> toJson() => _$TranscriptSegmentToJson(this);

  /// Format timestamp as HH:MM:SS.mmm
  static String formatTimestamp(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$secs.$millis';
  }
}
