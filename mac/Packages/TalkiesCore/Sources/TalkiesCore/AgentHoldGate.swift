import Foundation

/// Decides when a press of the agent key becomes an agent capture.
///
/// A press has no side effects until it qualifies: the key is held alone for
/// `AgentHotkey.minimumHoldSeconds` with no other key, modifier, or mouse button. Only then does
/// the app show the HUD, close history, open the microphone, or pause a pending send. A press that
/// turns out to be a shortcut (⌘V, ⌘-click, ⌘Tab held in the app switcher) is dropped silently.
public struct AgentHoldGate: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        /// Key is down alone; waiting for the hold to qualify.
        case arming(since: Date)
        /// The hold qualified and a capture is running.
        case capturing
        /// The press was part of a shortcut; ignore everything until the key is released.
        case rejected
    }

    public enum Action: Equatable, Sendable {
        case none
        /// Show the HUD and start an agent capture.
        case startCapture
        /// Key released after a qualified hold: finish the capture and transcribe it.
        case finishCapture
        /// A shortcut was detected after capture started: discard it without transcribing.
        case discardCapture
    }

    public private(set) var state: State = .idle
    public let minimumHold: TimeInterval

    public init(minimumHold: TimeInterval = AgentHotkey.minimumHoldSeconds) {
        self.minimumHold = minimumHold
    }

    /// The agent key went down. `isSolePress` is false when another modifier is already held.
    public mutating func keyDown(isSolePress: Bool, at time: Date) -> Action {
        guard state == .idle else { return .none }
        state = isSolePress ? .arming(since: time) : .rejected
        return .none
    }

    /// The hold timer fired, or any later check. Starts the capture once the hold qualifies.
    public mutating func tick(at time: Date) -> Action {
        guard case .arming(let since) = state, time.timeIntervalSince(since) >= minimumHold else { return .none }
        state = .capturing
        return .startCapture
    }

    /// Another key, another modifier, or a mouse button went down during the hold.
    public mutating func interrupted() -> Action {
        switch state {
        case .idle, .rejected:
            return .none
        case .arming:
            state = .rejected
            return .none
        case .capturing:
            state = .rejected
            return .discardCapture
        }
    }

    /// The agent key was released.
    public mutating func keyUp(at time: Date) -> Action {
        defer { state = .idle }
        switch state {
        case .capturing:
            return .finishCapture
        case .idle, .arming, .rejected:
            // A tap, or a shortcut: nothing was shown or recorded.
            return .none
        }
    }

    /// The capture could not start or ended elsewhere; forget it without further actions.
    public mutating func captureUnavailable() {
        if state == .capturing { state = .rejected }
    }
}
