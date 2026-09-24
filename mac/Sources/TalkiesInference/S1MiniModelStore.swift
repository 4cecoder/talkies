import CryptoKit
import Foundation

/// Keeps the pinned GGUF weights and their license notices on the local device.
actor S1MiniModelStore {
    private struct Artifact: Sendable {
        let name: String
        let size: Int?
        let sha256: String?
    }

    private static let artifacts = [
        Artifact(
            name: "s1-mini-q4_k_m.gguf",
            size: 484_219_808,
            sha256: "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634"
        ),
        Artifact(name: "LICENSE", size: nil, sha256: nil),
        Artifact(name: "NOTICE", size: nil, sha256: nil),
    ]

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 3_600
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    private var cachedModelURL: URL?

    func ensureModelAvailable() async throws -> URL {
        if let cachedModelURL, FileManager.default.fileExists(atPath: cachedModelURL.path) {
            return cachedModelURL
        }

        let directory = try Self.modelDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for artifact in Self.artifacts {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(artifact.name)
            if try isValid(destination, artifact: artifact) { continue }
            try await download(artifact, to: destination)
        }
        let modelURL = directory.appendingPathComponent("s1-mini-q4_k_m.gguf")
        cachedModelURL = modelURL
        return modelURL
    }

    private func download(_ artifact: Artifact, to destination: URL) async throws {
        var components = URLComponents(string: "https://huggingface.co")!
        components.path = "/superwhisper/s1-mini-GGUF/resolve/\(S1MiniCleaner.modelRevision)/\(artifact.name)"
        components.queryItems = [URLQueryItem(name: "download", value: "true")]
        guard let url = components.url else { throw S1MiniModelStoreError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (temporaryURL, response) = try await session.download(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw S1MiniModelStoreError.invalidResponse
        }
        guard try isValid(temporaryURL, artifact: artifact) else {
            throw S1MiniModelStoreError.integrityFailure(artifact.name)
        }

        let partialURL = destination.appendingPathExtension("partial")
        try? FileManager.default.removeItem(at: partialURL)
        try FileManager.default.moveItem(at: temporaryURL, to: partialURL)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: partialURL, to: destination)
    }

    private func isValid(_ url: URL, artifact: Artifact) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        if let expectedSize = artifact.size {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard values.fileSize == expectedSize else { return false }
        }
        guard let expectedHash = artifact.sha256 else { return true }
        return try sha256(of: url) == expectedHash
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func modelDirectory() throws -> URL {
        guard let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw S1MiniModelStoreError.cacheUnavailable
        }
        return supportDirectory
            .appendingPathComponent("Talkies/Models/S1-mini-\(S1MiniCleaner.modelRevision)", isDirectory: true)
    }
}

private enum S1MiniModelStoreError: LocalizedError {
    case invalidURL
    case invalidResponse
    case integrityFailure(String)
    case cacheUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The pinned S1-mini model URL is invalid."
        case .invalidResponse:
            "The S1-mini model download returned an invalid response."
        case .integrityFailure(let artifact):
            "The downloaded S1-mini file failed integrity verification: \(artifact)."
        case .cacheUnavailable:
            "Talkies could not locate a local directory for S1-mini model files."
        }
    }
}
