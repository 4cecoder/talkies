import Foundation
import TalkiesCore

/// `cmux --json --id-format uuids tree --all` (fields verified against cmux 0.65.0).
/// Only the fields Talkies uses are decoded; unknown fields are ignored.
public struct CmuxTree: Decodable, Equatable, Sendable {
    public let windows: [Window]

    public struct Window: Decodable, Equatable, Sendable {
        public let id: String
        public let workspaces: [Workspace]
    }

    public struct Workspace: Decodable, Equatable, Sendable {
        public let id: String
        public let index: Int?
        public let title: String?
        public let panes: [Pane]
    }

    public struct Pane: Decodable, Equatable, Sendable {
        public let id: String
        public let surfaces: [Surface]
    }

    public struct Surface: Decodable, Equatable, Sendable {
        public let id: String
        public let title: String?
        public let type: String?
        public let index: Int?
    }

    public static func decode(_ data: Data) throws -> CmuxTree {
        try CmuxJSON.decoder.decode(CmuxTree.self, from: data)
    }
}

/// `cmux rpc surface.input_state {"surface_id": …}`.
public struct CmuxInputState: Decodable, Equatable, Sendable {
    public let surfaceId: String?
    public let workspaceId: String?
    /// Whether the surface's foreground process is a detected agent.
    public let agent: Bool?
    public let terminal: Bool?
    /// `empty`, `draft`, `dialog`, or `unknown`.
    public let state: String?
    /// `running`, `idle`, `needsInput`, or `unknown`.
    public let lifecycle: String?
    public let blocksTyping: Bool?
    public let waitingOnHuman: Bool?

    public static func decode(_ data: Data) throws -> CmuxInputState {
        try CmuxJSON.decoder.decode(CmuxInputState.self, from: data)
    }

    public var isAgent: Bool { agent == true }

    public var inputState: AgentInputState {
        switch state {
        case "empty": .empty
        case "draft": .draft
        case "dialog": .dialog
        default: .unknown
        }
    }

    public var status: AgentStatus {
        if waitingOnHuman == true { return .needsInput }
        switch lifecycle {
        case "running": return .working
        case "idle": return .idle
        case "needsInput", "needs_input": return .needsInput
        case "done": return .done
        default: return .unknown
        }
    }
}

/// `cmux --json --id-format uuids list-notifications`.
public struct CmuxNotification: Decodable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let subtitle: String?
    public let body: String?
    public let surfaceId: String?
    public let workspaceId: String?
    public let createdAt: String?
    public let isRead: Bool?

    public static func decodeList(_ data: Data) throws -> [CmuxNotification] {
        try CmuxJSON.decoder.decode([CmuxNotification].self, from: data)
    }
}

enum CmuxJSON {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
