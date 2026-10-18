import Foundation

/// Closed command set of the agent-mode grammar, version 1:
///
/// ```text
/// utterance := [address ","] (command | prompt)
/// address   := <agent name or alias> | "agent" <number>
/// command   := status | list | read-last | show | approve | deny | interrupt
///            | send | cancel | confirm | remember <text> | recall <text>
/// prompt    := anything else
/// ```
public enum AgentCommand: String, Codable, Sendable, CaseIterable {
    case status
    case list
    case readLast = "read_last"
    case show
    case approve
    case deny
    case interrupt
    case send
    case cancel
    case confirm
    case remember
    case recall
}

/// Who an utterance is addressed to.
public enum AgentAddress: Equatable, Sendable {
    case agent(id: String)
    /// "agent 2": a position in the visible agent list, starting at 1.
    case number(Int)
    /// The spoken name matched several agents about equally well.
    case ambiguous(spoken: String, candidates: [String])
}

public enum AgentIntent: Equatable, Sendable {
    /// `argument` carries the free text of `remember` and `recall`.
    case command(AgentCommand, argument: String?)
    /// Prompt text for the addressed agent. Empty when the user only said a name.
    case prompt(String)
}

public struct AgentUtterance: Equatable, Sendable {
    public let address: AgentAddress?
    public let intent: AgentIntent

    public init(address: AgentAddress?, intent: AgentIntent) {
        self.address = address
        self.intent = intent
    }
}

/// Rules-based agent-mode parser. It uses no model and never guesses a command: anything
/// that does not match the closed grammar becomes prompt text for the addressed agent.
///
/// Only agent mode calls this parser. Text from the dictation hotkey is always inserted
/// verbatim (see `CaptureRouter`).
public struct AgentIntentParser: Sendable {
    public static let grammarVersion = 1
    /// A command is six words or fewer after the address; longer text is a prompt.
    public static let maxCommandWords = 6
    /// Longest leading address considered, in words.
    static let maxAddressWords = 4

    public let matcher: AgentNameMatcher

    public init(candidates: [AgentNameCandidate]) {
        matcher = AgentNameMatcher(candidates: candidates)
    }

    public init(agents: [AgentRef]) {
        self.init(candidates: agents.map(AgentNameCandidate.init(agent:)))
    }

    public func parse(_ text: String) -> AgentUtterance {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AgentUtterance(address: nil, intent: .prompt("")) }

        let (address, body) = splitAddress(trimmed)
        let intent = parseBody(body, hasAddress: address != nil)
        if case .command(_, _) = intent.intent, address == nil, let embedded = intent.address {
            return AgentUtterance(address: embedded, intent: intent.intent)
        }
        return AgentUtterance(address: address, intent: intent.intent)
    }

    // MARK: - Address

    private static let separators: Set<Character> = [",", ":", ".", "!", "?", ";"]
    private static let greetings: Set<String> = ["hey", "hi", "ok", "okay", "yo"]

    private func splitAddress(_ text: String) -> (AgentAddress?, String) {
        // 1. An explicit address ends at the first separator within the first few words.
        if let separatorIndex = text.firstIndex(where: { Self.separators.contains($0) }) {
            let prefix = String(text[..<separatorIndex])
            let prefixWords = AgentSpeechText.words(prefix)
            if !prefixWords.isEmpty, prefixWords.count <= Self.maxAddressWords + 1,
               let address = resolveAddress(prefixWords, threshold: AgentNameMatcher.addressThreshold) {
                return (address, Self.stripLeadingPunctuation(String(text[text.index(after: separatorIndex)...])))
            }
        }

        // 2. Otherwise try the leading words as a name ("Atlas run the tests").
        let tokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var best: (address: AgentAddress, score: Double, consumed: Int)?
        for count in 1...min(Self.maxAddressWords, tokens.count) {
            let words = AgentSpeechText.words(tokens.prefix(count).joined(separator: " "))
            guard !words.isEmpty else { continue }
            if let number = Self.agentNumber(words) {
                best = (.number(number), 2, count)
                break
            }
            let nameWords = Self.greetings.contains(words[0]) && words.count > 1 ? Array(words.dropFirst()) : words
            switch matcher.match(
                nameWords.joined(separator: " "),
                threshold: AgentNameMatcher.leadingNameThreshold,
                minimumEditSimilarity: AgentNameMatcher.leadingNameMinimumEdit
            ) {
            case .unique(let id, let score):
                if best == nil || score > best!.score { best = (.agent(id: id), score, count) }
            case .ambiguous(let ids):
                if best == nil || 1.0 > best!.score {
                    best = (.ambiguous(spoken: nameWords.joined(separator: " "), candidates: ids), 1.0, count)
                }
            case .none:
                break
            }
        }
        if let best {
            let remainder = tokens.dropFirst(best.consumed).joined(separator: " ")
            return (best.address, Self.stripLeadingPunctuation(remainder))
        }
        return (nil, text)
    }

    /// Resolves normalized address words to an agent, a list number, or an ambiguity.
    func resolveAddress(_ words: [String], threshold: Double) -> AgentAddress? {
        var words = words
        if words.count > 1, Self.greetings.contains(words[0]) { words.removeFirst() }
        if let number = Self.agentNumber(words) { return .number(number) }
        guard words.count <= Self.maxAddressWords else { return nil }
        let spoken = words.joined(separator: " ")
        switch matcher.match(spoken, threshold: threshold) {
        case .unique(let id, _): return .agent(id: id)
        case .ambiguous(let ids): return .ambiguous(spoken: spoken, candidates: ids)
        case .none: return nil
        }
    }

    /// "agent 2", "agent two", or the common mishearing "agent to".
    static func agentNumber(_ words: [String]) -> Int? {
        guard words.count == 2, ["agent", "agents", "age"].contains(words[0]) else { return nil }
        return AgentSpeechText.number(words[1])
    }

    // MARK: - Body

    private func parseBody(_ body: String, hasAddress: Bool) -> AgentUtterance {
        let words = AgentSpeechText.words(body)
        let prompt = AgentUtterance(address: nil, intent: .prompt(Self.capitalizeFirst(body)))
        guard !words.isEmpty else { return AgentUtterance(address: nil, intent: .prompt("")) }

        // remember/recall carry free text and target notes, not an agent. Addressed to an
        // agent, "Atlas, remember to rebase" is an ordinary prompt.
        if !hasAddress, let first = words.first, first == "remember" || first == "recall" {
            let argument = Self.textAfterFirstWord(body)
            return AgentUtterance(address: nil, intent: .command(first == "remember" ? .remember : .recall, argument: argument))
        }

        var commandWords = words
        while commandWords.count > 1, ["please", "can", "could", "would"].contains(commandWords[0]) {
            if commandWords[0] == "please" { commandWords.removeFirst(); continue }
            guard commandWords.count > 2, commandWords[1] == "you" else { break }
            commandWords.removeFirst(2)
        }
        while commandWords.count > 1, ["please", "now"].contains(commandWords[commandWords.count - 1]) {
            commandWords.removeLast()
        }
        guard words.count <= Self.maxCommandWords else { return prompt }

        let phrase = commandWords.joined(separator: " ")
        if let command = Self.phrases[phrase] {
            return AgentUtterance(address: nil, intent: .command(command, argument: nil))
        }
        if !hasAddress {
            for template in Self.templates {
                guard let spoken = template.capture(commandWords) else { continue }
                if Self.pronouns.contains(spoken.joined(separator: " ")) {
                    return AgentUtterance(address: nil, intent: .command(template.command, argument: nil))
                }
                if let address = resolveAddress(spoken, threshold: AgentNameMatcher.addressThreshold) {
                    return AgentUtterance(address: address, intent: .command(template.command, argument: nil))
                }
            }
        }
        return prompt
    }

    private static let pronouns: Set<String> = ["it", "he", "she", "they", "you", "that", "this"]

    private static let phrases: [String: AgentCommand] = {
        var table: [String: AgentCommand] = [:]
        func add(_ command: AgentCommand, _ phrases: [String]) {
            for phrase in phrases { table[phrase] = command }
        }
        add(.status, [
            "status", "your status", "status update", "status report", "give me a status", "give me status",
            "whats your status", "what is your status", "whats happening", "what is happening", "whats going on",
            "what are you doing", "how are you doing", "hows it going", "how is it going", "are you done",
            "are you finished", "progress", "whats the status",
        ])
        add(.list, [
            "list", "list agents", "list the agents", "list all agents", "list my agents", "which agents",
            "which agents are running", "what agents are running", "what agents are there", "show agents",
            "show all agents", "show me the agents", "show me all agents", "whos running", "who is running", "agents",
        ])
        add(.readLast, [
            "read last", "read the last message", "read last message", "read the last reply", "read last reply",
            "read the last response", "read me the last message", "last message", "what did you say", "read it back",
            "read back", "read that back", "what was the last message", "read the last one",
        ])
        add(.show, [
            "show", "show me", "show it", "focus", "show in cmux", "open it", "bring it up", "go there", "switch to it",
        ])
        add(.approve, [
            "approve", "approve it", "approve that", "approved", "a prove", "a prove it", "yes approve", "allow",
            "allow it", "allow once",
        ])
        add(.deny, ["deny", "deny it", "deny that", "denied", "reject", "reject it"])
        add(.interrupt, ["interrupt", "interrupt it", "stop", "stop it", "stop that", "halt"])
        add(.send, ["send", "send it", "send that", "send now"])
        add(.cancel, ["cancel", "cancel it", "cancel that", "never mind", "nevermind", "dont send", "do not send", "abort"])
        add(.confirm, ["confirm", "confirmed", "i confirm", "yes confirm"])
        return table
    }()

    /// Command phrases with the agent named inside them, such as "what's Atlas doing".
    private struct Template: Sendable {
        let command: AgentCommand
        let prefix: [String]
        let suffix: [String]

        init(_ command: AgentCommand, _ pattern: String) {
            self.command = command
            let parts = pattern.components(separatedBy: "{a}")
            prefix = parts[0].split(separator: " ").map(String.init)
            suffix = parts.count > 1 ? parts[1].split(separator: " ").map(String.init) : []
        }

        func capture(_ words: [String]) -> [String]? {
            guard words.count > prefix.count + suffix.count,
                  Array(words.prefix(prefix.count)) == prefix,
                  Array(words.suffix(suffix.count)) == suffix else { return nil }
            var spoken = Array(words.dropFirst(prefix.count).dropLast(suffix.count))
            // "read Atlas's last message" normalizes to "atlass"; keep the possessive optional.
            if spoken.count == 1, prefix.last == "read", spoken[0].hasSuffix("s") {
                spoken[0].removeLast()
            }
            return spoken
        }
    }

    private static let templates: [Template] = [
        Template(.status, "whats {a} doing"), Template(.status, "what is {a} doing"),
        Template(.status, "hows {a} doing"), Template(.status, "how is {a} doing"),
        Template(.status, "whats {a} up to"), Template(.status, "what is {a} up to"),
        Template(.status, "status of {a}"), Template(.status, "status for {a}"),
        Template(.status, "is {a} done"), Template(.status, "is {a} finished"), Template(.status, "check on {a}"),
        Template(.readLast, "what did {a} say"), Template(.readLast, "read the last message from {a}"),
        Template(.readLast, "read last message from {a}"), Template(.readLast, "read {a} last message"),
        Template(.show, "show me {a}"), Template(.show, "show {a} in cmux"), Template(.show, "show {a}"),
        Template(.show, "focus on {a}"), Template(.show, "focus {a}"), Template(.show, "switch to {a}"),
        Template(.show, "go to {a}"), Template(.show, "open {a}"),
    ]

    // MARK: - Text helpers

    static func stripLeadingPunctuation(_ text: String) -> String {
        String(text.drop(while: { $0.isWhitespace || $0.isPunctuation }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func capitalizeFirst(_ text: String) -> String {
        let trimmed = stripLeadingPunctuation(text)
        guard let first = trimmed.first else { return "" }
        return first.uppercased() + trimmed.dropFirst()
    }

    private static func textAfterFirstWord(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let space = trimmed.firstIndex(where: { $0.isWhitespace || $0 == ":" || $0 == "," }) else { return "" }
        var rest = stripLeadingPunctuation(String(trimmed[space...]))
        if rest.lowercased().hasPrefix("that ") { rest = String(rest.dropFirst(5)) }
        return capitalizeFirst(rest)
    }
}
