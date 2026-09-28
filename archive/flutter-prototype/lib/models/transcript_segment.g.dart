// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranscriptSegment _$TranscriptSegmentFromJson(Map<String, dynamic> json) =>
    TranscriptSegment(
      text: json['text'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$TranscriptSegmentToJson(TranscriptSegment instance) =>
    <String, dynamic>{
      'text': instance.text,
      'start': instance.start,
      'end': instance.end,
      'timestamp': instance.timestamp,
    };
