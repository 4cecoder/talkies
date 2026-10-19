import Foundation

/// How a recorded utterance is used. The dictation hotkey always inserts text verbatim;
/// only the agent hotkey parses commands.
public enum CaptureMode: String, Codable, Sendable {
    case dictation
    case agent
}

/// Where finished text goes. Agent-mode text is handed on unparsed; the agent controller
/// parses it against the live agent list.
public enum CaptureRoute: Equatable, Sendable {
    case insert(String)
    case agent(String)
}

public enum CaptureRouter {
    public static func route(_ text: String, mode: CaptureMode) -> CaptureRoute {
        switch mode {
        case .dictation: .insert(text)
        case .agent: .agent(text)
        }
    }
}

/// Identifies one recording. It is created at key press and travels with the audio, so a
/// result is routed by the capture that produced it, never by whichever key was pressed last.
public struct CaptureTicket: Hashable, Sendable {
    public let id: UUID
    public let mode: CaptureMode

    public init(id: UUID = UUID(), mode: CaptureMode) {
        self.id = id
        self.mode = mode
    }
}

public enum CaptureOutcome<Destination> {
    /// Insert the text into the destination captured when this recording started.
    case insert(String, destination: Destination?)
    /// Hand the text to agent mode. It is never inserted.
    case agent(String)
    /// The capture was cancelled or already finished; its text is discarded.
    case dropped
}

/// Open captures and the insertion destination each was bound to at key press.
///
/// Transcriptions finish asynchronously and may overlap a newer key press. The ledger keeps
/// each capture's mode and destination with its ticket so an older dictation is never routed
/// to an agent, and an agent utterance is never typed into the focused app.
public struct CaptureLedger<Destination> {
    private var open: [UUID: (mode: CaptureMode, destination: Destination?)] = [:]

    public init() {}

    public mutating func begin(_ mode: CaptureMode, destination: Destination? = nil) -> CaptureTicket {
        let ticket = CaptureTicket(mode: mode)
        // An agent capture never carries an insertion destination.
        open[ticket.id] = (mode, mode == .dictation ? destination : nil)
        return ticket
    }

    /// The mode of a capture that is still open, or nil when it was cancelled or finished.
    public func mode(of ticket: CaptureTicket) -> CaptureMode? {
        open[ticket.id]?.mode
    }

    public var openCount: Int { open.count }

    /// Discards a capture; its result, if any arrives later, is dropped.
    public mutating func cancel(_ ticket: CaptureTicket) {
        open[ticket.id] = nil
    }

    /// Routes a finished capture's text and closes the capture.
    public mutating func finish(_ ticket: CaptureTicket, text: String) -> CaptureOutcome<Destination> {
        guard let entry = open.removeValue(forKey: ticket.id) else { return .dropped }
        switch CaptureRouter.route(text, mode: entry.mode) {
        case .insert(let text): return .insert(text, destination: entry.destination)
        case .agent(let text): return .agent(text)
        }
    }

    /// Closes a capture that produced no usable text and reports its mode.
    public mutating func finishWithoutText(_ ticket: CaptureTicket) -> CaptureMode? {
        open.removeValue(forKey: ticket.id)?.mode
    }
}
