import AppKit
import TalkiesCore

enum MenuBarStatusIcon {
    static func state(isRecording: Bool, stage: PipelineStage) -> MenuBarIconState {
        let activity: MenuBarIconState.Activity
        switch stage {
        case .idle: activity = .ready
        case .loadingModel: activity = .loading
        case .requestingMicrophonePermission, .clipboardFallback, .noSpeech, .error, .cleanupFallback:
            activity = .needsAttention
        case .recording: activity = .recording
        case .transcribing, .enhancingOllama, .enhancingLMStudio:
            activity = .recognizing
        case .cleaningS1Mini: activity = .polishing
        case .insertingText: activity = .inserting
        case .complete: activity = .completed
        }
        return MenuBarIconState(isRecording: isRecording, activity: activity)
    }

    static func image(for state: MenuBarIconState) -> NSImage {
        let image = NSImage(
            systemSymbolName: state.symbolName,
            accessibilityDescription: state.accessibilityLabel
        ) ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: state.accessibilityLabel)!
        image.isTemplate = true
        return image
    }
}
