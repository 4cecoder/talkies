import Foundation

/// Finds the cmux command-line tool.
public enum CmuxExecutableLocator {
    /// Location inside the installed app bundle (verified with cmux 0.65.0).
    public static let bundledPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    /// Candidate paths in priority order: the app bundle, a per-user app bundle, then `PATH`.
    /// GUI apps inherit a minimal `PATH`, so common Homebrew locations are appended.
    public static func candidates(environment: [String: String], homeDirectory: String) -> [String] {
        var paths = [
            bundledPath,
            (homeDirectory as NSString).appendingPathComponent("Applications/cmux.app/Contents/Resources/bin/cmux"),
        ]
        let searchPath = (environment["PATH"] ?? "").split(separator: ":").map(String.init) + ["/opt/homebrew/bin", "/usr/local/bin"]
        // Only absolute entries: a relative PATH entry would resolve against the working directory.
        for directory in searchPath where directory.hasPrefix("/") {
            paths.append((directory as NSString).appendingPathComponent("cmux"))
        }
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory(),
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL? {
        candidates(environment: environment, homeDirectory: homeDirectory)
            .first(where: isExecutable)
            .map { URL(fileURLWithPath: $0) }
    }
}

/// Argument arrays for every cmux call Talkies makes. Each array is passed straight to
/// `Process`; nothing here is ever joined into a shell string. Talkies always uses UUID
/// handles (`--id-format uuids`) because refs and indexes can shift.
public enum CmuxArguments {
    /// Name shown to the receiving agent as the sender.
    public static let senderName = "Talkies"

    public static func ping() -> [String] { ["ping"] }

    public static func tree() -> [String] {
        ["--json", "--id-format", "uuids", "tree", "--all"]
    }

    /// Read-only `surface.input_state`: draft/dialog state, agent detection, lifecycle.
    public static func inputState(surfaceID: String) throws -> [String] {
        let id = try validatedID(surfaceID)
        let params = try JSONSerialization.data(withJSONObject: ["surface_id": id], options: [.sortedKeys])
        return ["rpc", "surface.input_state", String(decoding: params, as: UTF8.self)]
    }

    public static func notifications() -> [String] {
        ["--json", "--id-format", "uuids", "list-notifications"]
    }

    public static func readScreen(workspaceID: String, surfaceID: String, lines: Int) throws -> [String] {
        [
            "read-screen",
            "--workspace", try validatedID(workspaceID),
            "--surface", try validatedID(surfaceID),
            "--lines", String(max(1, min(lines, 400))),
        ]
    }

    /// Prompt delivery through the agent's hooks. The text itself is written to stdin (`-`),
    /// never placed on argv, and `--force` is never passed.
    public static func agentMessage(surfaceID: String) throws -> [String] {
        ["agent", "message", try validatedID(surfaceID), "--from", senderName, "-"]
    }

    public static func selectWorkspace(workspaceID: String) throws -> [String] {
        ["select-workspace", "--workspace", try validatedID(workspaceID)]
    }

    public static func focusPanel(workspaceID: String, surfaceID: String) throws -> [String] {
        ["focus-panel", "--panel", try validatedID(surfaceID), "--workspace", try validatedID(workspaceID)]
    }

    /// Handles are UUIDs from cmux's own JSON. Anything else (for example a value starting
    /// with "-") is rejected so it can never be read as a flag.
    static func validatedID(_ id: String) throws -> String {
        guard let uuid = UUID(uuidString: id) else {
            throw CmuxArgumentError.invalidHandle(id)
        }
        return uuid.uuidString
    }
}

public enum CmuxArgumentError: Error, Equatable, Sendable {
    case invalidHandle(String)
}

/// Maps cmux CLI failures to actionable connector errors.
public enum CmuxErrorClassifier {
    public static let tool = "cmux"

    /// Shown when cmux's socket is in "cmux processes only" mode (verified: the CLI prints
    /// "Access denied - only processes started inside cmux can connect").
    public static let accessDeniedGuidance = """
        cmux only accepts commands from programs started inside cmux. In cmux, open Settings → Automation \
        and set Socket Control Mode to “Password mode”, then save the same password in Talkies Settings → Agents. \
        “Automation mode” also works without a password.
        """

    public static let passwordRequiredGuidance = """
        cmux needs its socket password. Copy it from cmux Settings → Automation and save it in \
        Talkies Settings → Agents.
        """

    public static let passwordRejectedGuidance = """
        cmux rejected the saved socket password. Update it in Talkies Settings → Agents to match \
        cmux Settings → Automation.
        """

    public static func classify(exitCode: Int32, standardError: String) -> AgentConnectorErrorKind {
        let message = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = message.lowercased()
        if lowered.contains("access denied") {
            return .accessDenied(accessDeniedGuidance)
        }
        if lowered.contains("invalid password") {
            return .accessDenied(passwordRejectedGuidance)
        }
        if lowered.contains("authentication required") || lowered.contains("missing password")
            || lowered.contains("no socket password is configured") {
            return .accessDenied(passwordRequiredGuidance)
        }
        if lowered.contains("socket not found") || lowered.contains("connection refused")
            || lowered.contains("control socket is disabled") {
            return .notRunning
        }
        if lowered.contains("not_found") || lowered.contains("not found") {
            return .notFound(cleaned(message))
        }
        return .failed(cleaned(message.isEmpty ? "exit status \(exitCode)" : message))
    }

    /// Strips cmux's "Error: ERROR: " prefixes.
    static func cleaned(_ message: String) -> String {
        var text = message
        for prefix in ["Error:", "ERROR:"] {
            while text.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) {
                text = String(text.trimmingCharacters(in: .whitespaces).dropFirst(prefix.count))
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum AgentConnectorErrorKind: Equatable, Sendable {
    case accessDenied(String)
    case notRunning
    case notFound(String)
    case failed(String)
}
