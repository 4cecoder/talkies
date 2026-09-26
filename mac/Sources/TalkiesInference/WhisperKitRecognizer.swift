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
    public func initialize(download: Bool = true, modelFolder: URL? = nil) async throws {
        guard whisperKit == nil else { return }
        whisperKit = try await WhisperKit(
            model: modelName,
            modelFolder: modelFolder?.path,
            tokenizerFolder: modelFolder,
            verbose: true,
            logLevel: .debug,
            download: download
        )
    }

    /// Transcribes a local audio file and returns framework-independent segments.
    public func transcribe(
        _ audioURL: URL,
        deleteAudioAfterProcessing: Bool = false,
        vocabulary: [String] = [],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [TranscriptSegment] {
        defer {
            if deleteAudioAfterProcessing {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }

        guard let whisperKit else {
            throw WhisperKitRecognizerError.notInitialized
        }

        var options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 5,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            clipTimestamps: [0]
        )
        let vocabularyPrompt = LocalVocabulary(terms: vocabulary).recognitionPrompt
        if !vocabularyPrompt.isEmpty, let tokenizer = whisperKit.tokenizer {
            let tokens = tokenizer.encode(text: " " + vocabularyPrompt)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            options.promptTokens = Array(tokens.prefix(128))
        }
        let progressCallback: @Sendable (TranscriptionProgress) -> Bool? = { progress in
            // WhisperKit reports token/window progress without a final token
            // count. This is an estimate based on 30-second audio windows and
            // the decoder token cap; keep it below 100 until decoding returns.
            let duration = max(progress.timings.inputAudioSeconds, 0.1)
            let estimatedWindowCount = max(1, ceil(duration / 30))
            let withinWindow = min(Double(progress.tokens.count) / 224, 0.95)
            let estimate = (Double(progress.windowId) + withinWindow) / estimatedWindowCount
            onProgress?(min(0.97, max(0.01, estimate)))
            return true
        }
        let results = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options,
            callback: progressCallback
        )
        onProgress?(0.99)

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

public enum WhisperKitRecognizerError: LocalizedError {
    case notInitialized

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Local speech recognizer not initialized"
        }
    }
}
