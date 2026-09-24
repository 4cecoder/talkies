import CryptoKit
import Foundation
import Hub
import MLXLMCommon

/// Downloads a pinned S1-mini model into the same local cache used by MLX.
/// Inference reads the cached directory only, so transcript text never reaches the network.
actor S1MiniModelStore {
    private struct Artifact: Sendable {
        let name: String
        let size: Int
        let sha256: String?
    }

    private static let artifacts = [
        Artifact(name: "config.json", size: 1_021, sha256: nil),
        Artifact(name: "generation_config.json", size: 181, sha256: nil),
        Artifact(name: "model.safetensors", size: 335_450_548, sha256: "284990f04854426d6164d634d8c472d7eb6e79c68f8fd8b4c8a80a4f234276ba"),
        Artifact(name: "model.safetensors.index.json", size: 49_770, sha256: nil),
        Artifact(name: "tokenizer.json", size: 11_422_650, sha256: "be75606093db2094d7cd20f3c2f385c212750648bd6ea4fb2bf507a6a4c55506"),
        Artifact(name: "tokenizer_config.json", size: 729, sha256: nil),
        Artifact(name: "chat_template.jinja", size: 4_168, sha256: nil),
        Artifact(name: "LICENSE", size: 11_878, sha256: nil),
    ]

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 3_600
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    func ensureModelAvailable(modelID: String, revision: String) async throws -> URL {
        let repo = Hub.Repo(id: modelID)
        let directory = defaultHubApi.localRepoLocation(repo)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for artifact in Self.artifacts {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(artifact.name)
            if try isValid(destination, artifact: artifact) {
                continue
            }
            try await download(artifact, revision: revision, to: destination)
        }
        return directory
    }

    private func download(_ artifact: Artifact, revision: String, to destination: URL) async throws {
        var components = URLComponents(string: "https://huggingface.co")!
        components.path = "/mlx-community/S1-mini-MLX-4bit/resolve/\(revision)/\(artifact.name)"
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
        guard FileManager.default.fileExists(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              values.fileSize == artifact.size else {
            return false
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
}

enum S1MiniModelStoreError: LocalizedError {
    case invalidURL
    case invalidResponse
    case integrityFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The pinned S1-mini model URL is invalid."
        case .invalidResponse:
            return "The S1-mini model download returned an invalid response."
        case .integrityFailure(let artifact):
            return "The downloaded S1-mini file failed integrity verification: \(artifact)."
        }
    }
}
