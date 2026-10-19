import Foundation
import TalkiesCore

/// Drives cmux through its installed CLI.
///
/// - Listing: `tree --all` plus a read-only `surface.input_state` per terminal surface.
/// - Delivery: `agent message <surface> -` only, with the prompt on stdin. cmux delivers it
///   through the agent's hooks rather than typing, and Talkies never passes `--force`.
/// - Before delivering, Talkies refuses when the target has a human draft or a dialog open,
///   or when its foreground process is not an agent.
/// - The socket password, when set, reaches the child only through `CMUX_SOCKET_PASSWORD`.
///
/// cmux has no structured approval or interrupt call, so this connector does not claim
/// those capabilities.
public struct CmuxConnector: AgentConnector {
    public let id = "cmux"
    public let displayName = "cmux"
    public let capabilities: AgentCapabilities = [.list, .read, .prompt, .show]
    /// Upper bound on parallel `surface.input_state` calls while listing.
    static let maxConcurrentCalls = 4

    private let executable: URL?
    private let runner: any CommandRunner
    private let socketPassword: @Sendable () -> String?

    public init(
        executable: URL? = CmuxExecutableLocator.locate(),
        runner: any CommandRunner = ProcessCommandRunner(),
        socketPassword: @escaping @Sendable () -> String? = { nil }
    ) {
        self.executable = executable
        self.runner = runner
        self.socketPassword = socketPassword
    }

    public var executablePath: String? { executable?.path }

    // MARK: - AgentConnector

    /// Checks that the socket accepts Talkies.
    public func ping() async throws {
        _ = try await call(CmuxArguments.ping())
    }

    public func list() async throws -> [AgentRef] {
        let tree = try await decode("tree") { try CmuxTree.decode(try await call(CmuxArguments.tree()).standardOutput) }
        let surfaceIDs = tree.windows.flatMap(\.workspaces).flatMap(\.panes).flatMap(\.surfaces)
            .filter { ($0.type ?? "terminal") == "terminal" }
            .map(\.id)

        let states = try await withThrowingTaskGroup(of: (String, CmuxInputState?).self) { group in
            var remaining = surfaceIDs[...]
            func addNext() {
                guard let surfaceID = remaining.popFirst() else { return }
                group.addTask {
                    do {
                        return (surfaceID, try await inputState(surfaceID: surfaceID))
                    } catch {
                        // A socket-level failure applies to every surface; report it once.
                        if let error = error as? AgentConnectorError, error.isSocketLevel { throw error }
                        return (surfaceID, nil)
                    }
                }
            }
            // At most `maxConcurrentCalls` cmux processes run at once.
            for _ in 0..<Self.maxConcurrentCalls { addNext() }
            var states: [String: CmuxInputState] = [:]
            while let (surfaceID, state) = try await group.next() {
                if let state { states[surfaceID] = state }
                addNext()
            }
            return states
        }
        return Self.agents(from: tree, inputStates: states)
    }

    public func status(of agent: AgentRef) async throws -> AgentStatusReport {
        let state = try await inputState(for: agent)
        return Self.report(for: agent, state: state)
    }

    public func readLast(_ agent: AgentRef, lines: Int) async throws -> String {
        let output = try await call(CmuxArguments.notifications())
        let notifications = (try? CmuxNotification.decodeList(output.standardOutput)) ?? []
        if let body = Self.latestNotificationBody(notifications, surfaceID: agent.id) {
            return body
        }
        guard let workspaceID = agent.workspaceID else { return "" }
        let screen = try await call(CmuxArguments.readScreen(workspaceID: workspaceID, surfaceID: agent.id, lines: lines))
        return screen.standardOutputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func prompt(_ agent: AgentRef, text: String) async throws -> AgentDeliveryResult {
        let state = try await inputState(for: agent)
        if let refusal = Self.deliveryRefusal(for: state) {
            return .refused(refusal)
        }
        do {
            _ = try await call(CmuxArguments.agentMessage(surfaceID: agent.id), standardInput: Data(text.utf8))
            return .delivered
        } catch AgentConnectorError.commandFailed(_, let message) {
            return .refused(.rejected(message))
        }
    }

    public func show(_ agent: AgentRef) async throws {
        guard let workspaceID = agent.workspaceID else {
            throw AgentConnectorError.agentNotFound(name: agent.name)
        }
        _ = try await call(CmuxArguments.selectWorkspace(workspaceID: workspaceID))
        _ = try await call(CmuxArguments.focusPanel(workspaceID: workspaceID, surfaceID: agent.id))
    }

    // MARK: - Pure mapping (unit-tested against recorded cmux JSON)

    /// Builds agent references from the tree and per-surface input states. Only surfaces whose
    /// foreground process cmux detects as an agent are listed. An agent alone in its workspace
    /// is named after the workspace ("Atlas"); agents sharing a workspace are named after their
    /// surface and share the workspace title as an alias, so the bare title asks "Which agent?".
    public static func agents(from tree: CmuxTree, inputStates: [String: CmuxInputState]) -> [AgentRef] {
        var agents: [AgentRef] = []
        for window in tree.windows {
            for workspace in window.workspaces {
                let surfaces = workspace.panes.flatMap(\.surfaces).filter { inputStates[$0.id]?.isAgent == true }
                let workspaceTitle = workspace.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                for surface in surfaces {
                    let surfaceTitle = surface.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name: String
                    var aliases: [String] = []
                    if surfaces.count == 1, let workspaceTitle, !workspaceTitle.isEmpty {
                        name = workspaceTitle
                        if let surfaceTitle, !surfaceTitle.isEmpty, surfaceTitle != workspaceTitle { aliases.append(surfaceTitle) }
                    } else {
                        name = (surfaceTitle?.isEmpty == false ? surfaceTitle : nil) ?? workspaceTitle ?? "Agent"
                        if let workspaceTitle, !workspaceTitle.isEmpty, workspaceTitle != name { aliases.append(workspaceTitle) }
                    }
                    agents.append(AgentRef(
                        connector: "cmux",
                        id: surface.id,
                        name: name,
                        aliases: aliases,
                        status: inputStates[surface.id]?.status ?? .unknown,
                        workspace: workspaceTitle,
                        workspaceID: workspace.id
                    ))
                }
            }
        }
        return agents
    }

    public static func report(for agent: AgentRef, state: CmuxInputState) -> AgentStatusReport {
        AgentStatusReport(
            agent: agent,
            status: state.status,
            inputState: state.inputState,
            waitingOnHuman: state.waitingOnHuman == true
        )
    }

    /// The delivery guard: never deliver into a human draft, a dialog, or a bare shell.
    public static func deliveryRefusal(for state: CmuxInputState) -> AgentDeliveryRefusal? {
        guard state.isAgent else { return .notAnAgent }
        switch state.inputState {
        case .draft: return .draftOpen
        case .dialog: return .dialogOpen
        case .empty, .unknown: return nil
        }
    }

    static func latestNotificationBody(_ notifications: [CmuxNotification], surfaceID: String) -> String? {
        notifications
            .filter { $0.surfaceId?.caseInsensitiveCompare(surfaceID) == .orderedSame }
            .filter { !($0.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .max { ($0.createdAt ?? "") < ($1.createdAt ?? "") }?
            .body
    }

    // MARK: - CLI calls

    private func inputState(for agent: AgentRef) async throws -> CmuxInputState {
        do {
            return try await inputState(surfaceID: agent.id)
        } catch AgentConnectorError.agentNotFound {
            throw AgentConnectorError.agentNotFound(name: agent.name)
        }
    }

    private func inputState(surfaceID: String) async throws -> CmuxInputState {
        let output = try await call(CmuxArguments.inputState(surfaceID: surfaceID))
        return try await decode("surface.input_state") { try CmuxInputState.decode(output.standardOutput) }
    }

    private func decode<T>(_ what: String, _ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as AgentConnectorError {
            throw error
        } catch {
            throw AgentConnectorError.malformedOutput(tool: displayName, detail: what)
        }
    }

    private func call(_ arguments: [String], standardInput: Data? = nil) async throws -> CommandOutput {
        guard let executable else { throw AgentConnectorError.toolNotInstalled(tool: displayName) }
        var environment: [String: String] = [:]
        if let password = socketPassword(), !password.isEmpty {
            environment["CMUX_SOCKET_PASSWORD"] = password
        }
        let invocation = CommandInvocation(executable: executable, arguments: arguments, environment: environment, standardInput: standardInput)

        let output: CommandOutput
        do {
            output = try await runner.run(invocation)
        } catch CommandRunnerError.executableMissing {
            throw AgentConnectorError.toolNotInstalled(tool: displayName)
        } catch CommandRunnerError.timedOut {
            throw AgentConnectorError.timedOut(tool: displayName)
        } catch CommandRunnerError.launchFailed(let message) {
            throw AgentConnectorError.commandFailed(tool: displayName, message: message)
        } catch CommandRunnerError.standardInputFailed(let message) {
            throw AgentConnectorError.commandFailed(tool: displayName, message: "it exited without reading the message (\(message))")
        }

        guard output.exitCode == 0 else {
            switch CmuxErrorClassifier.classify(exitCode: output.exitCode, standardError: output.standardErrorText + output.standardOutputText) {
            case .accessDenied(let guidance): throw AgentConnectorError.accessDenied(tool: displayName, guidance: guidance)
            case .notRunning: throw AgentConnectorError.toolNotRunning(tool: displayName)
            case .notFound(let message): throw AgentConnectorError.agentNotFound(name: message)
            case .failed(let message): throw AgentConnectorError.commandFailed(tool: displayName, message: message)
            }
        }
        return output
    }
}

extension AgentConnectorError {
    /// Failures that affect every call, not one surface.
    var isSocketLevel: Bool {
        switch self {
        case .accessDenied, .toolNotRunning, .toolNotInstalled, .timedOut: true
        default: false
        }
    }
}
