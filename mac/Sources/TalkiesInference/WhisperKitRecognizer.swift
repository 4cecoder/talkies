import Foundation
@preconcurrency import WhisperKit
import TalkiesCore

/// Owns the volatile WhisperKit model lifecycle and audio decoding boundary.
@MainActor
public final class WhisperKitRecognizer {
    private let modelName: String
    private var whisperKit: WhisperKit?

    public var isReady: Bool { whisperKit != nil }

    public init(modelName: String = "openai_whisper-base") {
        self.modelName = modelName
    }

    /// Loads the configured local model, downloading it on first use when needed.
    public func initialize() async throws {
        guard whisperKit == nil else { return }
        whisperKit = try await WhisperKit(
            model: modelName,
            verbose: true,
            logLevel: .debug
        )
    }

    /// Transcribes a local audio file and returns framework-independent segments.
    public func transcribe(_ audioURL: URL) async throws -> [TranscriptSegment] {
        guard let whisperKit else {
            throw WhisperKitRecognizerError.notInitialized
        }

        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 5,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            clipTimestamps: [0]
        )
        let results = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options
        )

        return results.flatMap { result in
            result.segments.map { segment in
                let start = Double(segment.start)
                return TranscriptSegment(
                    timestamp: Self.formatTimestamp(start),
                    text: segment.text,
                    start: start,
                    end: Double(segment.end)
                )
            }
        }
    }

    private static func formatTimestamp(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
}

public enum WhisperKitRecognizerError: Error {
    case notInitialized
}
