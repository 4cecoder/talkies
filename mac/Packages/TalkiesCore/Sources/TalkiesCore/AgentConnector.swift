import Foundation

// Agent-connector contract from docs/architecture/companion-and-agent-control.md.
// This file is Foundation-only: connector implementations (cmux, herdr, the built-in
// ACP harness) live in the high-volatility TalkiesConnectors package and map their
// native states into these types.

/// Normalized agent state. Connectors map native states into this enum
/// (cmux `needsInput` and herdr `blocked` both become `.needsInput`).
public enum AgentStatus: String, Codable, Sendable, CaseIterable {
    case idle
    case working
    case needsInput = "needs_input"
    case done
    case unknown

    /// Short phrase used in spoken status sentences.
    public var spokenPhrase: String {
        switch self {
        case .idle: "idle"
        case .working: "working"
        case .needsInput: "waiting for your answer"
        case .done: "done"
        case .unknown: "in an unknown state"
        }
    }
}

/// What a human or agent has open in an agent's input area.
public enum AgentInputState: String, Codable, Sendable {
    case empty
    /// The user has a half-typed prompt open. Delivery must not touch it.
    case draft
    /// The agent shows a dialog, such as a permission prompt.
    case dialog
    case unknown
}

/// Actions a connector can perform. A connector reports what it cannot do
/// instead of faking it, and the UI hides actions outside this set.
public struct AgentCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let list = AgentCapabilities(rawValue: 1 << 0)
    public static let statusEvents = AgentCapabilities(rawValue: 1 << 1)
    public static let read = AgentCapabilities(rawValue: 1 << 2)
    public static let prompt = AgentCapabilities(rawValue: 1 << 3)
    public static let interrupt = AgentCapabilities(rawValue: 1 << 4)
    public static let approve = AgentCapabilities(rawValue: 1 << 5)
    public static let spawn = AgentCapabilities(rawValue: 1 << 6)
    /// Focus or reveal the agent in its own UI ("Show in cmux").
    public static let show = AgentCapabilities(rawValue: 1 << 7)
}

/// One addressable agent. `id` is stable for the life of the agent (cmux surface UUID,
/// herdr agent id, or a Talkies harness id); refs and indexes are never stored.
public struct AgentRef: Identifiable, Hashable, Sendable, Codable {
    public let connector: String
    public let id: String
    public let name: String
    public let aliases: [String]
    /// Agent program when the connector knows it, for example "claude" or "codex".
    public let kind: String?
    public let status: AgentStatus
    /// Display title of the containing workspace, if any.
    public let workspace: String?
    public let workspaceID: String?
    public let cwd: String?

    public init(
        connector: String,
        id: String,
        name: String,
        aliases: [String] = [],
        kind: String? = nil,
        status: AgentStatus = .unknown,
        workspace: String? = nil,
        workspaceID: String? = nil,
        cwd: String? = nil
    ) {
        self.connector = connector
        self.id = id
        self.name = name
        self.aliases = aliases
        self.kind = kind
        self.status = status
        self.workspace = workspace
        self.workspaceID = workspaceID
        self.cwd = cwd
    }

    /// Target string used by the companion protocol: `agent:<connector>/<id>`.
    public var target: String { "agent:\(connector)/\(id)" }

    /// Every spoken form this agent answers to, name first.
    public var spokenNames: [String] { [name] + aliases }
}

/// Read-only snapshot used for status replies. Text fields that come from the agent are
/// untrusted: they are shown or spoken, never parsed for intents.
public struct AgentStatusReport: Equatable, Sendable {
    public let agent: AgentRef
    public let status: AgentStatus
    public let inputState: AgentInputState
    public let waitingOnHuman: Bool
    /// Most recent agent message or notification body, untrusted.
    public let lastMessage: String?

    public init(agent: AgentRef, status: AgentStatus, inputState: AgentInputState, waitingOnHuman: Bool, lastMessage: String? = nil) {
        self.agent = agent
        self.status = status
        self.inputState = inputState
        self.waitingOnHuman = waitingOnHuman
        self.lastMessage = lastMessage
    }
}

/// Why a connector declined to deliver prompt text. Nothing was typed in any of these cases.
public enum AgentDeliveryRefusal: Equatable, Sendable {
    /// A human draft is open in the agent's input area.
    case draftOpen
    /// The agent shows a dialog (for example a permission prompt).
    case dialogOpen
    /// The target's foreground process is not a detected agent, such as a bare shell.
    case notAnAgent
    /// The tool rejected the delivery; the message is the tool's own explanation.
    case rejected(String)
}

public enum AgentDeliveryResult: Equatable, Sendable {
    case delivered
    case refused(AgentDeliveryRefusal)
}

/// Connector failures with user-facing, actionable descriptions.
public enum AgentConnectorError: Error, Equatable, Sendable, LocalizedError {
    /// The tool's CLI or socket is not installed.
    case toolNotInstalled(tool: String)
    /// The tool is installed but not running.
    case toolNotRunning(tool: String)
    /// The tool's control socket refused this process. `guidance` explains how to allow it.
    case accessDenied(tool: String, guidance: String)
    case agentNotFound(name: String)
    case unsupported(action: String, tool: String)
    case commandFailed(tool: String, message: String)
    case malformedOutput(tool: String, detail: String)
    case timedOut(tool: String)

    public var errorDescription: String? {
        switch self {
        case .toolNotInstalled(let tool):
            "\(tool) isn't installed. Install it, or choose another agent connector."
        case .toolNotRunning(let tool):
            "\(tool) isn't running. Open \(tool) and try again."
        case .accessDenied(_, let guidance):
            guidance
        case .agentNotFound(let name):
            "\(name) is no longer running."
        case .unsupported(let action, let tool):
            "\(tool) can't \(action) from Talkies."
        case .commandFailed(let tool, let message):
            "\(tool) reported an error: \(message)"
        case .malformedOutput(let tool, let detail):
            "Talkies couldn't read \(tool)'s reply (\(detail))."
        case .timedOut(let tool):
            "\(tool) didn't answer in time."
        }
    }
}

/// A source of agents that Talkies can address by voice.
///
/// Implementations call their tool with argument arrays or structured socket calls,
/// never through a shell. Prompt delivery must never submit text to a shell.
public protocol AgentConnector: Sendable {
    /// Connector identifier: "talkies", "cmux", or "herdr".
    var id: String { get }
    /// Human-readable tool name used in messages.
    var displayName: String { get }
    var capabilities: AgentCapabilities { get }

    func list() async throws -> [AgentRef]
    func status(of agent: AgentRef) async throws -> AgentStatusReport
    /// Recent agent output. The result is untrusted text.
    func readLast(_ agent: AgentRef, lines: Int) async throws -> String
    /// Delivers prompt text to an agent. Refuses rather than typing when a draft or dialog is open.
    func prompt(_ agent: AgentRef, text: String) async throws -> AgentDeliveryResult
    /// Reveals the agent in the connector's own UI.
    func show(_ agent: AgentRef) async throws
    func interrupt(_ agent: AgentRef) async throws
    /// Answers a structured permission request. `decision` is only allow-once or deny.
    func respond(_ agent: AgentRef, requestRef: String, decision: AgentApprovalDecision) async throws
}

public enum AgentApprovalDecision: String, Codable, Sendable {
    case allowOnce = "allow_once"
    case deny
}

public extension AgentConnector {
    func interrupt(_ agent: AgentRef) async throws {
        throw AgentConnectorError.unsupported(action: "interrupt agents", tool: displayName)
    }

    func respond(_ agent: AgentRef, requestRef: String, decision: AgentApprovalDecision) async throws {
        throw AgentConnectorError.unsupported(action: "answer permission requests", tool: displayName)
    }
}
