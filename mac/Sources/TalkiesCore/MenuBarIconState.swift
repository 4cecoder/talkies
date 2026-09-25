/// Semantic status shown in the macOS menu bar. Kept separate from AppKit so
/// state selection can be tested without fragile image snapshots.
public enum MenuBarIconState: Equatable, Sendable {
    public enum Activity: Sendable {
        case ready
        case loading
        case recording
        case recognizing
        case polishing
        case inserting
        case completed
        case needsAttention
    }

    case ready
    case loading
    case recording
    case recognizing
    case polishing
    case inserting
    case completed
    case needsAttention

    public init(isRecording: Bool, activity: Activity) {
        if isRecording {
            self = .recording
            return
        }

        switch activity {
        case .ready: self = .ready
        case .loading: self = .loading
        case .recording: self = .recording
        case .recognizing: self = .recognizing
        case .polishing: self = .polishing
        case .inserting: self = .inserting
        case .completed: self = .completed
        case .needsAttention: self = .needsAttention
        }
    }

    public var symbolName: String {
        switch self {
        case .ready: "waveform"
        case .loading: "arrow.down.circle"
        case .recording: "waveform.circle.fill"
        case .recognizing: "waveform.path"
        case .polishing: "sparkles"
        case .inserting: "text.cursor"
        case .completed: "checkmark.circle.fill"
        case .needsAttention: "exclamationmark.bubble.fill"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .ready: "Talkies ready"
        case .loading: "Talkies is loading the speech model"
        case .recording: "Talkies is recording"
        case .recognizing: "Talkies is transcribing"
        case .polishing: "Talkies is polishing your transcript"
        case .inserting: "Talkies is inserting text"
        case .completed: "Talkies finished"
        case .needsAttention: "Talkies needs your attention"
        }
    }
}
