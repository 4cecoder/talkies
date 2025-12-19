import Foundation

/// Exports transcript segments to WebVTT format
/// - Parameter segments: Array of transcript segments to export
/// - Returns: WebVTT formatted string
public func exportVTT(segments: [TranscriptSegment]) -> String {
    var output = "WEBVTT\n\n"

    for (index, segment) in segments.enumerated() {
        output += "\(index + 1)\n"
        output += "\(formatTimestamp(time: segment.start)) --> \(formatTimestamp(time: segment.end))\n"
        output += "\(segment.text)\n\n"
    }

    return output
}

/// Exports transcript segments to SRT (SubRip) format
/// - Parameter segments: Array of transcript segments to export
/// - Returns: SRT formatted string
public func exportSRT(segments: [TranscriptSegment]) -> String {
    var output = ""

    for (index, segment) in segments.enumerated() {
        output += "\(index + 1)\n"
        output += "\(formatSRTTime(time: segment.start)) --> \(formatSRTTime(time: segment.end))\n"
        output += "\(segment.text)\n\n"
    }

    return output
}

/// Exports transcript segments to plain text format
/// - Parameter segments: Array of transcript segments to export
/// - Returns: Plain text string with timestamps
public func exportTXT(segments: [TranscriptSegment]) -> String {
    var output = ""

    for segment in segments {
        output += "[\(segment.timestamp)] \(segment.text)\n"
    }

    return output
}
