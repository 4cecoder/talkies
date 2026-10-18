import AppKit
import AVFoundation
import Combine
import TalkiesConnectors
import TalkiesCore

/// Agent mode state for the HUD: target selection, intent handling through the safety gate,
/// the tier-1 cancel window, and spoken status replies.
///
/// Only the agent hotkey reaches `handle(_:)`. Dictation text never comes here.
@MainActor
final class AgentModeController: ObservableObject {
    struct PendingAction: Equatable, Identifiable {
        enum Kind: Equatable {
            case prompt(String)
            case show
        }

        let id = UUID()
        let agent: AgentRef
        let kind: Kind
        let startedAt: Date
        let deadline: Date
        /// The agent hotkey was pressed during the window: the send waits for that utterance.
        var isHeld = false
        /// Why the send is still waiting, shown on its card.
        var note: String?
    }

    struct Notice: Equatable {
        enum Tone: Equatable { case info, success, warning, error }

        let text: String
        let tone: Tone
        /// The cmux socket refused Talkies; offer the setup shortcuts.
        var needsSocketSetup = false
    }

    enum Phase: Equatable {
        case idle
        case listening
        case working(String)
        case pending(PendingAction)
        case notice(Notice)
        /// The spoken name matched several agents; the user picks one.
        case choosing(candidates: [AgentRef], intent: AgentIntent)
    }

    @Published private(set) var agents: [AgentRef] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastListError: String?
    @Published var selectedTargetID: String?
    /// A dictation capture owns the HUD: agent notices must not cover its status.
    @Published var isDictationInProgress = false
    /// Display name of the configured agent key, or nil when none is chosen yet.
    @Published var agentKeyName: String?

    let connector: any AgentConnector
    private let gate = AgentSafetyGate.phase1
    private let cancelWindowSeconds: Double
    private let speechEnabled: @MainActor () -> Bool
    private let speaker: @MainActor (String) -> Void
    private let confirmationSound: @MainActor () -> Void
    private var pendingTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var lastListErrorIsAccessDenied = false
    private let speech = AVSpeechSynthesizer()

    /// - Parameters:
    ///   - speaker: Speaks a reply; defaults to the on-device `AVSpeechSynthesizer`.
    init(
        connector: any AgentConnector = CmuxConnector(socketPassword: { CmuxSocketPassword.read() }),
        cancelWindowSeconds: Double = AgentSafetyGate.cancelWindowSeconds,
        speechEnabled: @escaping @MainActor () -> Bool = { SettingsService.shared.settings.agentMode?.speakReplies ?? true },
        speaker: (@MainActor (String) -> Void)? = nil,
        confirmationSound: @escaping @MainActor () -> Void = { NSSound(named: "Tink")?.play() }
    ) {
        self.connector = connector
        self.cancelWindowSeconds = cancelWindowSeconds
        self.speechEnabled = speechEnabled
        self.confirmationSound = confirmationSound
        let synthesizer = speech
        self.speaker = speaker ?? { text in
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.speak(AVSpeechUtterance(string: text))
        }
    }

    var isActive: Bool { phase != .idle }

    /// Whether the HUD should show the agent panel now.
    var showsPanel: Bool { isActive && !isDictationInProgress }

    var selectedTarget: AgentRef? {
        agents.first { $0.id == selectedTargetID }
    }

    /// Agent names and aliases, added to the recognition vocabulary for agent-mode captures only.
    var spokenNames: [String] {
        agents.flatMap(\.spokenNames)
    }

    func number(of agent: AgentRef) -> Int? {
        agents.firstIndex { $0.id == agent.id }.map { $0 + 1 }
    }

    // MARK: - Listing

    @discardableResult
    func refreshAgents() async -> Bool {
        do {
            agents = try await connector.list()
            lastListError = nil
            lastListErrorIsAccessDenied = false
            if let selectedTargetID, !agents.contains(where: { $0.id == selectedTargetID }) {
                self.selectedTargetID = nil
            }
            return true
        } catch {
            lastListError = error.localizedDescription
            lastListErrorIsAccessDenied = Self.isAccessDenied(error)
            return false
        }
    }

    func select(_ agent: AgentRef) {
        selectedTargetID = agent.id
        // Match by id: the listed status may have changed since the choice was offered.
        if case .choosing(let candidates, let intent) = phase, candidates.contains(where: { $0.id == agent.id }) {
            Task { await run(intent, on: agent) }
        }
    }

    // MARK: - Capture lifecycle

    func beginListening() {
        speech.stopSpeaking(at: .immediate)
        noticeTask?.cancel()
        isDictationInProgress = false
        if holdPending() { return }
        phase = .listening
    }

    /// Stops a pending send's countdown. A held send waits for an explicit Send or Cancel.
    @discardableResult
    func holdPending() -> Bool {
        guard var pending = currentPending else { return false }
        pendingTask?.cancel()
        pendingTask = nil
        pending.isHeld = true
        phase = .pending(pending)
        return true
    }

    /// The capture was empty, failed, or was discarded. A held send stays held: it is never
    /// restarted or sent without an explicit Send.
    func captureEndedWithoutSpeech() {
        if phase == .listening { phase = .idle }
    }

    func dismiss() {
        cancelPending(announce: false)
        noticeTask?.cancel()
        speech.stopSpeaking(at: .immediate)
        phase = .idle
    }

    /// A dictation capture started: hold any pending send so it can't fire unseen, and keep
    /// agent notices from covering the dictation status.
    func dictationStarted() {
        holdPending()
        isDictationInProgress = true
    }

    // MARK: - Utterances

    func handle(_ text: String) async {
        // "cancel" and "send" act on a pending send at once, before any cmux call.
        let quick = AgentIntentParser(agents: agents).parse(text)
        if case .command(let command, _) = quick.intent, command == .cancel || command == .send {
            guard let pending = currentPending else {
                report(command == .cancel ? "Nothing to cancel." : "Nothing is waiting to send.", tone: .info)
                return
            }
            if command == .cancel {
                cancelPending(announce: true)
            } else if addresses(quick.address, pending.agent) {
                await firePendingNow()
            } else {
                // "Borealis, send" must not deliver a message addressed to Atlas.
                holdPending()
                report("The waiting message is for \(pending.agent.name). Say “send” or choose Send now.", tone: .warning, speak: true, keepPending: true)
            }
            return
        }
        // Any other utterance replaces a held send; failing toward "not sent" is the safe direction.
        if let pending = currentPending {
            cancelPending(announce: false)
            report("The message to \(pending.agent.name) was cancelled.", tone: .info)
        }

        phase = .working("Checking agents…")
        guard await refreshAgents() else {
            report(lastListError ?? "Couldn't reach cmux.", tone: .error, socketSetup: lastListErrorIsAccessDenied)
            return
        }

        let utterance = AgentIntentParser(agents: agents).parse(text)

        if case .command(.list, _) = utterance.intent {
            if case .refuse(let refusal) = gate.evaluate(utterance.intent, capabilities: connector.capabilities) {
                report(refusal.message, tone: .warning)
            } else {
                report(AgentStatusSentence.list(agents), tone: .info, speak: true)
            }
            return
        }

        let target: AgentRef
        switch utterance.address {
        case .agent(let id)?:
            guard let agent = agents.first(where: { $0.id == id }) else {
                report("That agent is no longer running.", tone: .warning)
                return
            }
            target = agent
        case .number(let number)?:
            guard agents.indices.contains(number - 1) else {
                report("There's no agent \(number). \(AgentStatusSentence.list(agents))", tone: .warning, speak: true)
                return
            }
            target = agents[number - 1]
        case .ambiguous(_, let ids)?:
            let candidates = agents.filter { ids.contains($0.id) }
            ask(candidates, intent: utterance.intent)
            return
        case nil:
            guard let selected = selectedTarget else {
                if agents.isEmpty {
                    report("No cmux agents are running.", tone: .warning, speak: true)
                } else {
                    ask(agents, intent: utterance.intent)
                }
                return
            }
            target = selected
        }

        selectedTargetID = target.id
        if case .prompt(let body) = utterance.intent, body.isEmpty {
            report("\(target.name) selected. Say what it should do.", tone: .info)
            return
        }
        await run(utterance.intent, on: target)
    }

    private func ask(_ candidates: [AgentRef], intent: AgentIntent) {
        let names = candidates.map(\.name)
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " or " + (names.last ?? "") : (names.first ?? "")
        phase = .choosing(candidates: candidates, intent: intent)
        speak("Which agent? \(list).")
    }

    /// Runs one intent through the safety gate.
    private func run(_ intent: AgentIntent, on agent: AgentRef) async {
        switch gate.evaluate(intent, capabilities: connector.capabilities) {
        case .refuse(let refusal):
            report(refusal.message, tone: .warning, speak: true)
        case .confirm:
            // Phase 1 has no tier-2 confirmations; the gate never returns this today.
            report(AgentGateRefusal.confirmationUnavailable.message, tone: .warning)
        case .runNow:
            await runImmediately(intent, on: agent)
        case .cancelWindow(let seconds):
            switch intent {
            case .prompt(let text): startCancelWindow(.prompt(text), agent: agent, seconds: min(seconds, cancelWindowSeconds))
            case .command(.show, _): startCancelWindow(.show, agent: agent, seconds: min(seconds, cancelWindowSeconds))
            case .command(let command, _): report(AgentGateRefusal.notAvailableYet(command).message, tone: .warning)
            }
        }
    }

    private func runImmediately(_ intent: AgentIntent, on agent: AgentRef) async {
        guard case .command(let command, _) = intent else { return }
        phase = .working(command == .status ? "Checking \(agent.name)…" : "Reading \(agent.name)…")
        do {
            switch command {
            case .status:
                let report = try await connector.status(of: agent)
                self.report(AgentStatusSentence.make(report, number: number(of: agent)), tone: .info, speak: true)
            case .readLast:
                // Agent output is untrusted: it is shown and spoken, never parsed.
                let text = try await connector.readLast(agent, lines: 40)
                if text.isEmpty {
                    report("\(agent.name) has no recent message.", tone: .info, speak: true)
                } else {
                    report("\(agent.name): \(AgentStatusSentence.spokenExcerpt(text))", tone: .info, speak: true)
                }
            default:
                report(AgentGateRefusal.notAvailableYet(command).message, tone: .warning)
            }
        } catch {
            report(error.localizedDescription, tone: .error, socketSetup: Self.isAccessDenied(error))
        }
    }

    // MARK: - Cancel window

    private var currentPending: PendingAction? {
        if case .pending(let pending) = phase { return pending }
        return nil
    }

    private func startCancelWindow(_ kind: PendingAction.Kind, agent: AgentRef, seconds: Double) {
        cancelPending(announce: false)
        let now = Date()
        let pending = PendingAction(agent: agent, kind: kind, startedAt: now, deadline: now.addingTimeInterval(seconds))
        phase = .pending(pending)
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await self?.fire(pending)
        }
    }

    func cancelPending(announce: Bool = true) {
        pendingTask?.cancel()
        pendingTask = nil
        guard let pending = currentPending else { return }
        if announce {
            report("Cancelled. Nothing was sent to \(pending.agent.name).", tone: .info)
        } else {
            phase = .idle
        }
    }

    func firePendingNow() async {
        guard let pending = currentPending else { return }
        pendingTask?.cancel()
        pendingTask = nil
        await fire(pending)
    }

    private func fire(_ pending: PendingAction) async {
        guard currentPending?.id == pending.id else { return }
        pendingTask = nil
        let agent = pending.agent
        switch pending.kind {
        case .prompt(let text):
            phase = .working("Sending to \(agent.name)…")
            do {
                switch try await connector.prompt(agent, text: text) {
                case .delivered:
                    confirmationSound()
                    report("Sent to \(agent.name).", tone: .success)
                case .refused(let refusal):
                    report(Self.message(for: refusal, agent: agent), tone: .warning, speak: true)
                }
            } catch {
                report(error.localizedDescription, tone: .error, socketSetup: Self.isAccessDenied(error))
            }
        case .show:
            phase = .working("Opening \(agent.name)…")
            do {
                try await connector.show(agent)
                Self.activateCmux()
                report("Showing \(agent.name) in cmux.", tone: .success)
            } catch {
                report(error.localizedDescription, tone: .error, socketSetup: Self.isAccessDenied(error))
            }
        }
    }

    static func message(for refusal: AgentDeliveryRefusal, agent: AgentRef) -> String {
        switch refusal {
        case .draftOpen:
            "\(agent.name) has a draft open, so nothing was sent. Finish or clear the draft in cmux, then try again."
        case .dialogOpen:
            "\(agent.name) is showing a question, so nothing was sent. Answer it in cmux first."
        case .notAnAgent:
            "\(agent.name) isn't running an agent right now, so nothing was sent."
        case .rejected(let reason):
            "cmux didn't deliver the message to \(agent.name): \(reason)"
        }
    }

    // MARK: - Feedback

    /// Whether an optional address names `agent` (no address counts as a match).
    private func addresses(_ address: AgentAddress?, _ agent: AgentRef) -> Bool {
        switch address {
        case nil: true
        case .agent(let id)?: id == agent.id
        case .number(let number)?: agents.indices.contains(number - 1) && agents[number - 1].id == agent.id
        case .ambiguous?: false
        }
    }

    private static func isAccessDenied(_ error: Error) -> Bool {
        if case AgentConnectorError.accessDenied = error { return true }
        return false
    }

    /// - Parameter keepPending: Show the text on the held send's card instead of replacing it.
    private func report(_ text: String, tone: Notice.Tone, speak shouldSpeak: Bool = false, socketSetup: Bool = false, keepPending: Bool = false) {
        if keepPending, var pending = currentPending {
            pending.note = text
            phase = .pending(pending)
            if shouldSpeak { speak(text) }
            return
        }
        phase = .notice(Notice(text: text, tone: tone, needsSocketSetup: socketSetup))
        if shouldSpeak { speak(text) }
        noticeTask?.cancel()
        let hold: Double = tone == .error || socketSetup ? 20 : 8
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled, let self, case .notice = self.phase else { return }
            self.phase = .idle
        }
    }

    private func speak(_ text: String) {
        guard speechEnabled() else { return }
        speaker(text)
    }

    static func activateCmux() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.cmuxterm.app").first?.activate()
    }

    static func openCmux() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.cmuxterm.app") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
