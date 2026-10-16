import Foundation
import TalkiesCore

/// A local speech-recognition runtime. Implementations own their model lifecycle.
@MainActor
public protocol LocalSpeechRecognizer: AnyObject {
    var runtimeID: SpeechRuntimeID { get }
    var isReady: Bool { get }
    /// Cheap check that the model files are on disk, so preparing needs no download.
    var isInstalledLocally: Bool { get }
    /// Loads the model, downloading verified files on first use when allowed.
    func prepare() async throws
    /// Transcribes a local audio file. Must not delete the file; the caller owns it.
    func transcribe(
        _ audioURL: URL,
        vocabulary: [String],
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> [TranscriptSegment]
}

/// Tries runtimes in preference order and falls back to the next one when a runtime
/// cannot load or fails to transcribe. Empty results are returned as-is (no speech).
@MainActor
public final class SpeechRecognizerChain {
    public struct Attempt: Sendable, Equatable {
        public let runtime: SpeechRuntimeID
        public let error: String
    }

    public struct Result: Sendable {
        public let segments: [TranscriptSegment]
        public let runtime: SpeechRuntimeID
        /// Runtimes that failed before `runtime` succeeded.
        public let fallbacks: [Attempt]
    }

    private let recognizers: [SpeechRuntimeID: any LocalSpeechRecognizer]

    public init(recognizers: [any LocalSpeechRecognizer]) {
        self.recognizers = Dictionary(recognizers.map { ($0.runtimeID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func isReady(_ preference: SpeechEnginePreference) -> Bool {
        preference.runtimeOrder.first.flatMap { recognizers[$0]?.isReady } ?? false
    }

    /// Starts loading the preferred runtime ahead of use. While it is not ready, already-installed
    /// fallbacks are loaded too, so a first-run Phonon-2 compile never blocks dictation.
    public func prewarm(_ preference: SpeechEnginePreference) {
        let candidates = preference.runtimeOrder.compactMap { recognizers[$0] }
        guard let first = candidates.first, !first.isReady else { return }
        Task { try? await first.prepare() }
        for fallback in candidates.dropFirst() where !fallback.isReady && fallback.isInstalledLocally {
            Task { try? await fallback.prepare() }
        }
    }

    public func transcribe(
        _ audioURL: URL,
        preference: SpeechEnginePreference,
        vocabulary: [String] = [],
        onRuntimeChange: ((SpeechRuntimeID) -> Void)? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Result {
        var failures: [Attempt] = []
        var lastError: Error = SpeechRecognizerChainError.noRuntimeAvailable

        let order = preference.runtimeOrder
        for (index, id) in order.enumerated() {
            guard let recognizer = recognizers[id] else { continue }
            try Task.checkCancellation()
            // Phonon-2's one-time Neural Engine compile can take minutes. Don't make a
            // dictation wait on it when a later runtime is already loaded; keep preparing.
            if !recognizer.isReady, order[(index + 1)...].contains(where: { recognizers[$0]?.isReady == true }) {
                Task { try? await recognizer.prepare() }
                failures.append(Attempt(runtime: id, error: SpeechRecognizerChainError.stillPreparing.localizedDescription))
                continue
            }
            onRuntimeChange?(id)
            do {
                try await recognizer.prepare()
                let segments = try await recognizer.transcribe(audioURL, vocabulary: vocabulary, onProgress: onProgress)
                return Result(segments: segments, runtime: id, fallbacks: failures)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failures.append(Attempt(runtime: id, error: error.localizedDescription))
                lastError = error
            }
        }
        throw lastError
    }
}

public enum SpeechRecognizerChainError: LocalizedError {
    case noRuntimeAvailable
    case stillPreparing

    public var errorDescription: String? {
        switch self {
        case .noRuntimeAvailable: "No local speech recognizer is available."
        case .stillPreparing: "The speech model is still being prepared."
        }
    }
}
