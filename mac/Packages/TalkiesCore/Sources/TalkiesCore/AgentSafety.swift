import Foundation

/// Safety tiers for voice-triggered actions.
public enum AgentActionTier: Int, Comparable, Sendable {
    /// status, list, read last message, recall: run immediately.
    case read = 0
    /// send a prompt, show an agent, interrupt, retain: run after a visible cancel window.
    case reversible = 1
    /// approve a permission request, prompt an auto-approving agent: explicit confirmation.
    case consequential = 2
    /// shell commands, spawning or closing agents, "always allow", scopes: Settings UI only.
    case neverByVoice = 3

    public static func < (lhs: AgentActionTier, rhs: AgentActionTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

public extension AgentCommand {
    var tier: AgentActionTier {
        switch self {
        case .status, .list, .readLast, .recall: .read
        // Deny, cancel, and "send now" are in the safe or already-confirmed direction.
        case .deny, .cancel, .send: .read
        case .show, .interrupt, .remember: .reversible
        case .approve, .confirm: .consequential
        }
    }

    /// Connector capability the command needs, if any.
    var requiredCapability: AgentCapabilities? {
        switch self {
        case .status, .list: .list
        case .readLast: .read
        case .show: .show
        case .interrupt: .interrupt
        case .approve, .deny, .confirm: .approve
        case .send: .prompt
        case .cancel, .remember, .recall: nil
        }
    }
}

public enum AgentGateRefusal: Equatable, Sendable {
    /// The command is part of the grammar but not enabled in this release.
    case notAvailableYet(AgentCommand)
    /// The addressed connector cannot perform this action.
    case connectorCannot(AgentCommand)
    /// The action needs explicit confirmation, which this release does not offer.
    case confirmationUnavailable
    case neverByVoice

    public var message: String {
        switch self {
        case .notAvailableYet(.approve), .notAvailableYet(.deny), .notAvailableYet(.confirm):
            "Approvals aren't available by voice yet. Answer the request in the agent's window."
        case .notAvailableYet(.remember), .notAvailableYet(.recall):
            "Voice notes aren't available yet. Nothing was saved or sent."
        case .notAvailableYet(let command):
            "“\(command.spokenName)” isn't available by voice yet."
        case .connectorCannot(let command):
            "This agent's connector can't \(command.spokenName)."
        case .confirmationUnavailable:
            "This action needs a confirmation step that isn't available yet. Nothing was sent."
        case .neverByVoice:
            "That action is only available in Settings."
        }
    }
}

public extension AgentCommand {
    var spokenName: String {
        switch self {
        case .readLast: "read the last message"
        default: rawValue
        }
    }
}

public enum AgentGateDecision: Equatable, Sendable {
    case runNow
    /// Show the action with a cancel control and run it when the window ends.
    case cancelWindow(seconds: Double)
    case confirm(timeoutSeconds: Double)
    case refuse(AgentGateRefusal)
}

/// The single gate every agent action passes through, whether it came from speech or a tap.
public struct AgentSafetyGate: Sendable {
    public static let cancelWindowSeconds = 2.0
    public static let confirmationTimeoutSeconds = 15.0

    /// Commands enabled in this release. Prompts are governed separately.
    public let enabledCommands: Set<AgentCommand>
    /// Whether tier-2 confirmations exist yet.
    public let allowsConfirmation: Bool

    public init(enabledCommands: Set<AgentCommand>, allowsConfirmation: Bool) {
        self.enabledCommands = enabledCommands
        self.allowsConfirmation = allowsConfirmation
    }

    /// Phase 1: tiers 0 and 1 only — status, list, read-last, show, and prompt delivery,
    /// plus cancel and send-now for a pending delivery. No approvals.
    public static let phase1 = AgentSafetyGate(
        enabledCommands: [.status, .list, .readLast, .show, .send, .cancel],
        allowsConfirmation: false
    )

    /// - Parameters:
    ///   - capabilities: The addressed connector's capabilities.
    ///   - targetAutoApproves: The target runs tools without asking, so a prompt is effectively a command.
    ///     Phase 1 limit: no connector reports this yet, so callers always pass `false`. The tier-2
    ///     path is implemented and tested so it is ready when connectors can detect auto-approve modes.
    public func evaluate(_ intent: AgentIntent, capabilities: AgentCapabilities, targetAutoApproves: Bool = false) -> AgentGateDecision {
        switch intent {
        case .prompt:
            guard capabilities.contains(.prompt) else { return .refuse(.connectorCannot(.send)) }
            if targetAutoApproves {
                return allowsConfirmation
                    ? .confirm(timeoutSeconds: Self.confirmationTimeoutSeconds)
                    : .refuse(.confirmationUnavailable)
            }
            return .cancelWindow(seconds: Self.cancelWindowSeconds)

        case .command(let command, _):
            guard enabledCommands.contains(command) else { return .refuse(.notAvailableYet(command)) }
            if let required = command.requiredCapability, !capabilities.contains(required) {
                return .refuse(.connectorCannot(command))
            }
            switch command.tier {
            case .read: return .runNow
            case .reversible: return .cancelWindow(seconds: Self.cancelWindowSeconds)
            case .consequential:
                return allowsConfirmation
                    ? .confirm(timeoutSeconds: Self.confirmationTimeoutSeconds)
                    : .refuse(.confirmationUnavailable)
            case .neverByVoice: return .refuse(.neverByVoice)
            }
        }
    }
}

/// Builds short status sentences from connector data, without a language model.
public enum AgentStatusSentence {
    /// "Agent 2, Borealis, in workspace talkies: working. No questions waiting."
    public static func make(_ report: AgentStatusReport, number: Int?) -> String {
        let agent = report.agent
        var sentence = number.map { "Agent \($0), \(agent.name)" } ?? agent.name
        if let workspace = agent.workspace, !workspace.isEmpty,
           AgentSpeechText.normalize(workspace) != AgentSpeechText.normalize(agent.name) {
            sentence += ", in workspace \(workspace)"
        }
        sentence += ": \(report.status.spokenPhrase)."
        if report.waitingOnHuman || report.status == .needsInput {
            sentence += " A question is waiting."
        } else if report.inputState == .dialog {
            sentence += " A dialog is open."
        } else {
            sentence += " No questions waiting."
        }
        if report.inputState == .draft {
            sentence += " A draft is open."
        }
        return sentence
    }

    /// "2 agents. 1, Atlas, working. 2, Borealis, idle."
    public static func list(_ agents: [AgentRef]) -> String {
        guard !agents.isEmpty else { return "No agents are running." }
        let count = agents.count == 1 ? "1 agent." : "\(agents.count) agents."
        let entries = agents.enumerated().map { index, agent in
            "\(index + 1), \(agent.name), \(agent.status.spokenPhrase)."
        }
        return ([count] + entries).joined(separator: " ")
    }

    /// Cuts untrusted agent text at a sentence boundary so it fits about a minute of speech.
    public static func spokenExcerpt(_ text: String, maxWords: Int = 150) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard words.count > maxWords else { return trimmed }

        var excerpt = ""
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { sentence, _, _, stop in
            guard let sentence else { return }
            let candidate = excerpt.isEmpty ? sentence : excerpt + sentence
            if candidate.split(whereSeparator: { $0.isWhitespace }).count > maxWords {
                stop = true
                return
            }
            excerpt = candidate
        }
        if excerpt.isEmpty {
            excerpt = words.prefix(maxWords).joined(separator: " ")
        }
        return excerpt.trimmingCharacters(in: .whitespacesAndNewlines) + " More on the screen."
    }
}

/// Modifier-only hotkeys for agent mode. Device-specific flag masks distinguish left from
/// right keys, so agent mode never fires on the dictation key.
public enum AgentHotkey: Int, CaseIterable, Codable, Sendable, Identifiable {
    case leftOption = 58
    case rightOption = 61
    case rightCommand = 54
    case rightControl = 62
    case rightShift = 60

    public var id: Int { rawValue }

    /// Device-independent family bit (`NSEvent.ModifierFlags`) of this key.
    public var familyFlagMask: UInt {
        switch self {
        case .leftOption, .rightOption: 1 << 19
        case .rightCommand: 1 << 20
        case .rightControl: 1 << 18
        case .rightShift: 1 << 17
        }
    }

    /// Shift, Control, Option, and Command family bits. Caps Lock and Fn are ignored.
    public static let modifierFamiliesMask: UInt = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)

    /// Whether `rawFlags` (an `NSEvent.modifierFlags.rawValue`) has this key down and no other
    /// modifier. Agent mode ignores a press that is part of a shortcut such as ⌘C or ⌘Tab.
    public func isSolePress(rawFlags: UInt) -> Bool {
        rawFlags & deviceFlagMask != 0 && rawFlags & Self.modifierFamiliesMask == familyFlagMask
            && rawFlags & otherDeviceBitsInFamily == 0
    }

    /// The opposite-side key of the same family (for example Left Command for Right Command).
    private var otherDeviceBitsInFamily: UInt {
        switch self {
        case .leftOption: 0x0000_0040
        case .rightOption: 0x0000_0020
        case .rightCommand: 0x0000_0008
        case .rightControl: 0x0000_0001
        case .rightShift: 0x0000_0002
        }
    }

    /// Minimum hold for an agent capture. Agent mode is hold-to-talk only: a shorter press is
    /// discarded instead of leaving the microphone open.
    public static let minimumHoldSeconds = 0.35

    public var keyCode: Int { rawValue }

    /// NX_DEVICE*KEYMASK bit for this physical key in `NSEvent.modifierFlags.rawValue`.
    public var deviceFlagMask: UInt {
        switch self {
        case .leftOption: 0x0000_0020
        case .rightOption: 0x0000_0040
        case .rightCommand: 0x0000_0010
        case .rightControl: 0x0000_2000
        case .rightShift: 0x0000_0004
        }
    }

    public var displayName: String {
        switch self {
        case .leftOption: "Left Option (⌥)"
        case .rightOption: "Right Option (⌥)"
        case .rightCommand: "Right Command (⌘)"
        case .rightControl: "Right Control (⌃)"
        case .rightShift: "Right Shift (⇧)"
        }
    }

    /// Whether this key is the same physical key as the dictation hotkey.
    public func conflicts(with dictationKey: ActivationKey) -> Bool {
        keyCode == dictationKey.rawValue
    }
}
