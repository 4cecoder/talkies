import Foundation

/// Supported single-key activation shortcuts for the macOS menu-bar app.
/// These key codes match the hardware key codes reported by NSEvent.
public enum ActivationKey: Int, CaseIterable, Codable, Sendable, Identifiable {
    case leftOption = 58
    case rightOption = 61

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .leftOption: "Left Option (⌥)"
        case .rightOption: "Right Option (⌥)"
        }
    }
}

/// A serializable copy of one representation on a system clipboard item.
public struct ClipboardRepresentation: Codable, Equatable, Sendable {
    public let type: String
    public let data: Data

    public init(type: String, data: Data) {
        self.type = type
        self.data = data
    }
}

/// Preserves every item and representation while Talkies temporarily uses the clipboard to paste text.
public struct ClipboardSnapshot: Codable, Equatable, Sendable {
    public let items: [[ClipboardRepresentation]]

    public init(items: [[ClipboardRepresentation]]) {
        self.items = items
    }
}

/// Represents a single segment of transcribed audio
public struct TranscriptSegment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: String
    public let text: String
    public let start: Double
    public let end: Double

    public init(id: UUID = UUID(), timestamp: String, text: String, start: Double, end: Double) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.start = start
        self.end = end
    }

    enum CodingKeys: String, CodingKey {
        case timestamp, text, start, end
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.timestamp = try container.decode(String.self, forKey: .timestamp)
        self.text = try container.decode(String.self, forKey: .text)
        self.start = try container.decode(Double.self, forKey: .start)
        self.end = try container.decode(Double.self, forKey: .end)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(text, forKey: .text)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
    }
}
