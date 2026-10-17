import Foundation

/// Local speech-recognition runtimes Talkies can run on this Mac.
public enum SpeechRuntimeID: String, Codable, Sendable, CaseIterable {
    /// Phonon-2 (compressed Parakeet TDT) on Core ML. English only.
    case phonon
    /// WhisperKit on Core ML. Multilingual; kept as the fallback runtime.
    case whisper

    public var displayName: String {
        switch self {
        case .phonon: "Phonon-2"
        case .whisper: "Whisper"
        }
    }
}

/// The user's speech-engine preference.
public enum SpeechEnginePreference: String, Codable, Sendable, CaseIterable {
    /// Phonon-2 for English dictation, falling back to Whisper when it is unavailable or fails.
    case automatic
    /// Whisper only, for dictation in languages other than English.
    case whisper

    public var displayName: String {
        switch self {
        case .automatic: "Phonon-2 (English), Whisper fallback"
        case .whisper: "Whisper (multilingual)"
        }
    }

    /// Ordered runtimes to try. Whisper is always last so a Phonon-2 failure never ends dictation.
    public var runtimeOrder: [SpeechRuntimeID] {
        switch self {
        case .automatic: [.phonon, .whisper]
        case .whisper: [.whisper]
        }
    }
}
