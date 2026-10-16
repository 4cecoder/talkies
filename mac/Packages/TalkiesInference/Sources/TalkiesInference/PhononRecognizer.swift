import Foundation
@preconcurrency import PhononCoreML
import TalkiesCore

/// Owns the Phonon-2 Core ML lifecycle. English only; the app falls back to Whisper when this fails.
@MainActor
public final class PhononRecognizer: LocalSpeechRecognizer {
    /// `Transcriber` serializes its own model access but is not marked Sendable.
    private final class TranscriberBox: @unchecked Sendable {
        let transcriber: Transcriber
        init(_ transcriber: Transcriber) { self.transcriber = transcriber }
    }

    public nonisolated let runtimeID: SpeechRuntimeID = .phonon
    public static var downloadSizeBytes: Int { PhononModelStore.totalDownloadBytes }

    private let store: PhononModelStore
    private let allowDownload: Bool
    private var box: TranscriberBox?
    private var loadTask: Task<TranscriberBox, Error>?

    public var isReady: Bool { box != nil }

    /// Size-only check; `prepare` still verifies every SHA-256 before loading.
    public var isInstalledLocally: Bool { store.hasExpectedFileSizes }

    public init(allowDownload: Bool = true, modelDirectory: URL? = nil) {
        store = PhononModelStore(directory: modelDirectory)
        self.allowDownload = allowDownload
    }

    public func prepare() async throws {
        if box != nil { return }
        if let loadTask {
            box = try await loadTask.value
            return
        }
        let store = store
        let allowDownload = allowDownload
        let task = Task.detached(priority: .userInitiated) { () throws -> TranscriberBox in
            let bundle: URL
            if allowDownload {
                bundle = try await store.ensureBundleAvailable()
            } else if let installed = try await store.installedBundle() {
                bundle = installed
            } else {
                throw PhononRecognizerError.modelNotInstalled
            }
            // First load compiles the encoder for the Neural Engine (a minute or two, once).
            return TranscriberBox(try Transcriber(bundle: bundle))
        }
        loadTask = task
        do {
            box = try await task.value
        } catch {
            loadTask = nil
            throw error
        }
    }

    public func transcribe(
        _ audioURL: URL,
        vocabulary: [String] = [],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [TranscriptSegment] {
        // Phonon-2 has no prompt or hotword input in the Swift package; vocabulary
        // is still applied by downstream cleanup.
        guard let box else { throw PhononRecognizerError.notInitialized }
        onProgress?(0.05)
        let transcript = try await Task.detached(priority: .userInitiated) {
            try box.transcriber.transcribe(url: audioURL)
        }.value
        onProgress?(0.99)
        return Self.segments(from: transcript.segments, fallbackText: transcript.text, duration: transcript.audioSeconds)
    }

    nonisolated static func segments(
        from segments: [PhononCoreML.Segment],
        fallbackText: String,
        duration: Double
    ) -> [TranscriptSegment] {
        let mapped = segments.compactMap { segment -> TranscriptSegment? in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TranscriptSegment(
                timestamp: TranscriptTimestamp.format(segment.start),
                text: text,
                start: segment.start,
                end: segment.end
            )
        }
        if !mapped.isEmpty { return mapped }
        let text = fallbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return [TranscriptSegment(timestamp: TranscriptTimestamp.format(0), text: text, start: 0, end: duration)]
    }
}

public enum PhononRecognizerError: LocalizedError {
    case notInitialized
    case modelNotInstalled

    public var errorDescription: String? {
        switch self {
        case .notInitialized: "Phonon-2 is not initialized."
        case .modelNotInstalled: "The Phonon-2 model is not installed."
        }
    }
}

enum TranscriptTimestamp {
    static func format(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
}
