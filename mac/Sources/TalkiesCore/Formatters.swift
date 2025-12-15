import Foundation

/// Formats a time value in seconds to HH:MM:SS.mmm format
/// - Parameter time: Time in seconds
/// - Returns: Formatted string in HH:MM:SS.mmm format
public func formatTimestamp(time: Double) -> String {
    let hours = Int(time) / 3600
    let minutes = (Int(time) % 3600) / 60
    let seconds = Int(time) % 60
    let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

    return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
}

/// Formats a time value in seconds to SRT format (HH:MM:SS,mmm with comma)
/// - Parameter time: Time in seconds
/// - Returns: Formatted string in HH:MM:SS,mmm format
public func formatSRTTime(time: Double) -> String {
    let hours = Int(time) / 3600
    let minutes = (Int(time) % 3600) / 60
    let seconds = Int(time) % 60
    let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

    return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
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
