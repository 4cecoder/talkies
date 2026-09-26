import Foundation

private func timestampParts(time: Double) -> (hours: Int, minutes: Int, seconds: Int, milliseconds: Int) {
    let totalMilliseconds = Int((max(time, 0) * 1_000).rounded(.toNearestOrAwayFromZero))
    return (
        hours: totalMilliseconds / 3_600_000,
        minutes: (totalMilliseconds / 60_000) % 60,
        seconds: (totalMilliseconds / 1_000) % 60,
        milliseconds: totalMilliseconds % 1_000
    )
}

/// Formats a time value in seconds to HH:MM:SS.mmm format
/// - Parameter time: Time in seconds
/// - Returns: Formatted string in HH:MM:SS.mmm format
public func formatTimestamp(time: Double) -> String {
    let parts = timestampParts(time: time)

    return String(format: "%02d:%02d:%02d.%03d", parts.hours, parts.minutes, parts.seconds, parts.milliseconds)
}

/// Formats a time value in seconds to SRT format (HH:MM:SS,mmm with comma)
/// - Parameter time: Time in seconds
/// - Returns: Formatted string in HH:MM:SS,mmm format
public func formatSRTTime(time: Double) -> String {
    let parts = timestampParts(time: time)

    return String(format: "%02d:%02d:%02d,%03d", parts.hours, parts.minutes, parts.seconds, parts.milliseconds)
}

/// Formats a duration in seconds to MM:SS format
/// - Parameter seconds: Duration in seconds
/// - Returns: Formatted string in MM:SS format
public func formatDuration(seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let minutes = totalSeconds / 60
    let remainingSeconds = totalSeconds % 60

    return String(format: "%02d:%02d", minutes, remainingSeconds)
}
