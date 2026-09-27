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

    /// Downloads a model through the local recognizer adapter without exposing WhisperKit to app clients.
    public static func downloadModel(variant: String) async throws -> URL {
        try await WhisperKit.download(variant: variant)
    }

    /// Loads the configured local model, downloading it on first use when needed.
    public func initialize(download: Bool = true, modelFolder: URL? = nil) async throws {
        guard whisperKit == nil else { return }

        let verifiedModelFolder = modelFolder.flatMap {
            Self.verifiedModelFolder($0, modelName: modelName)
        } ?? (modelFolder == nil ? Self.cachedModelFolder(modelName: modelName) : nil)
        let useVerifiedLocalCache = verifiedModelFolder != nil
        let selectedModelFolder = verifiedModelFolder ?? (download ? nil : modelFolder)
        whisperKit = try await WhisperKit(
            model: modelName,
            modelFolder: selectedModelFolder?.path,
            tokenizerFolder: useVerifiedLocalCache
                ? Self.defaultDownloadBase()
                : selectedModelFolder,
            verbose: true,
            logLevel: .debug,
            // WhisperKit's download helper queries Hugging Face for variant
            // metadata even when the complete model is already cached. Passing
            // the resolved local folder avoids that network request on every
            // launch/reinstall while still allowing the first run to download.
            download: Self.shouldDownload(requested: download, hasVerifiedCache: useVerifiedLocalCache)
        )
    }

    nonisolated static func shouldDownload(requested: Bool, hasVerifiedCache: Bool) -> Bool {
        requested && !hasVerifiedCache
    }

    nonisolated static func cachedModelFolder(modelName: String, downloadBase: URL? = nil) -> URL? {
        guard let downloadBase = downloadBase ?? defaultDownloadBase() else { return nil }
        let folder = downloadBase
            .appending(path: "models/argmaxinc/whisperkit-coreml")
            .appending(path: modelName, directoryHint: .isDirectory)
        return verifiedModelFolder(folder, modelName: modelName, downloadBase: downloadBase)
    }

    nonisolated static func verifiedModelFolder(
        _ folder: URL,
        modelName: String,
        downloadBase: URL? = nil
    ) -> URL? {
        let requiredModelPaths = [
            "config.json",
            "AudioEncoder.mlmodelc/weights/weight.bin",
            "MelSpectrogram.mlmodelc/weights/weight.bin",
            "TextDecoder.mlmodelc/weights/weight.bin",
        ]
        guard requiredModelPaths.allSatisfy({ Self.isNonEmptyFile(folder.appending(path: $0)) }) else {
            return nil
        }

        // WhisperKit ships the tokenizer alongside downloaded Core ML models.
        // Older cache layouts may keep it in the separate tokenizer repo.
        let tokenizerPath = modelName.replacingOccurrences(of: "openai_", with: "")
        let tokenizerLocations = [
            folder.appending(path: "models/openai/\(tokenizerPath)/tokenizer.json"),
            folder.appending(path: "tokenizer.json"),
            downloadBase?.appending(path: "models/openai/\(tokenizerPath)/tokenizer.json"),
        ]
        guard tokenizerLocations.compactMap({ $0 }).contains(where: Self.isNonEmptyFile) else { return nil }
        return folder
    }

    nonisolated private static func isNonEmptyFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else {
            return false
        }
        return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }

    nonisolated private static func defaultDownloadBase() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appending(path: "huggingface", directoryHint: .isDirectory)
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
