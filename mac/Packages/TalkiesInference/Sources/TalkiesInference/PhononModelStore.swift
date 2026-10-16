import CryptoKit
import Foundation

/// Keeps the pinned Phonon-2 Core ML bundle and its license notices on the local device.
actor PhononModelStore {
    struct Artifact: Sendable, Equatable {
        let path: String
        let size: Int
        let sha256: String
    }

    static let repository = "FermionResearch/Phonon-2-CoreML"
    static let revision = "1143812fd4236522232a8c33e3115f0577e3cd7d"

    /// Sizes and hashes from the repository's SHA256SUMS at `revision`.
    static let artifacts = [
        Artifact(
            path: "Phonon-2.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
            size: 329_186_560,
            sha256: "93aa991318a00ed492fdbb724e7bca4e6a69c6cf671ab4f14a14ef6101e7648b"
        ),
        Artifact(
            path: "Phonon-2.mlpackage/Data/com.apple.CoreML/model.mlmodel",
            size: 2_500_482,
            sha256: "4f6790ec94fe4429b10397c013563d0a51119953ff6d3da466bbcb23a25dee2a"
        ),
        Artifact(
            path: "Phonon-2.mlpackage/Manifest.json",
            size: 617,
            sha256: "6ebc9309aea0e16bda9c7558521fef6307fac0afba9a5b4959fea45ed7cd0429"
        ),
        Artifact(
            path: "decoder.bin",
            size: 13_301_279,
            sha256: "36fa7202dda85c603af60d930ab88d7e9f0d2a619490aff46f5384db924cfa70"
        ),
        Artifact(
            path: "manifest.json",
            size: 1_428,
            sha256: "ab3fb5dfd3fc07b1d8a24379d04418f458d0443ba6359d3a5ab2f098a7d64089"
        ),
        Artifact(
            path: "LICENSE-WEIGHTS-CC-BY-4.0.txt",
            size: 18_657,
            sha256: "9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411"
        ),
        Artifact(
            path: "LICENSE-CODE-Apache-2.0.txt",
            size: 11_358,
            sha256: "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
        ),
        Artifact(
            path: "NOTICE",
            size: 3_084,
            sha256: "b468a23a1ce2c5181ea4050432bb68713a6468ce2e452927228d24f3d56226be"
        ),
    ]

    static var totalDownloadBytes: Int { artifacts.reduce(0) { $0 + $1.size } }

    private let session: URLSession
    private nonisolated let directoryOverride: URL?
    private var verifiedBundleURL: URL?

    init(session: URLSession? = nil, directory: URL? = nil) {
        self.session = session ?? Self.makeSession()
        directoryOverride = directory
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 3_600
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    nonisolated var hasExpectedFileSizes: Bool {
        guard let directory = try? bundleDirectory() else { return false }
        return Self.artifacts.allSatisfy { artifact in
            let values = try? directory.appending(path: artifact.path).resourceValues(forKeys: [.fileSizeKey])
            return values?.fileSize == artifact.size
        }
    }

    /// Returns the bundle folder when every pinned file is already present and verified.
    func installedBundle() throws -> URL? {
        if let verifiedBundleURL { return verifiedBundleURL }
        let directory = try bundleDirectory()
        for artifact in Self.artifacts where !(try Self.isValid(directory.appending(path: artifact.path), artifact: artifact)) {
            return nil
        }
        verifiedBundleURL = directory
        return directory
    }

    /// Downloads any missing or invalid file from the pinned revision, verifying size and SHA-256.
    func ensureBundleAvailable() async throws -> URL {
        if let bundle = try installedBundle() { return bundle }
        let directory = try bundleDirectory()
        for artifact in Self.artifacts {
            try Task.checkCancellation()
            let destination = directory.appending(path: artifact.path)
            if try Self.isValid(destination, artifact: artifact) { continue }
            try await download(artifact, to: destination)
        }
        verifiedBundleURL = directory
        return directory
    }

    private func download(_ artifact: Artifact, to destination: URL) async throws {
        guard let url = Self.downloadURL(for: artifact) else { throw PhononModelStoreError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (temporaryURL, response) = try await session.download(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw PhononModelStoreError.invalidResponse
        }
        guard try Self.isValid(temporaryURL, artifact: artifact) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw PhononModelStoreError.integrityFailure(artifact.path)
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let partialURL = destination.appendingPathExtension("partial")
        try? FileManager.default.removeItem(at: partialURL)
        try FileManager.default.moveItem(at: temporaryURL, to: partialURL)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: partialURL, to: destination)
    }

    static func downloadURL(for artifact: Artifact) -> URL? {
        var components = URLComponents(string: "https://huggingface.co")
        components?.path = "/\(repository)/resolve/\(revision)/\(artifact.path)"
        components?.queryItems = [URLQueryItem(name: "download", value: "true")]
        return components?.url
    }

    static func isValid(_ url: URL, artifact: Artifact) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard values.fileSize == artifact.size else { return false }
        return try sha256(of: url) == artifact.sha256
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated func bundleDirectory() throws -> URL {
        if let directoryOverride { return directoryOverride }
        guard let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw PhononModelStoreError.cacheUnavailable
        }
        return supportDirectory
            .appending(path: "Talkies/Models/Phonon-2-CoreML-\(Self.revision)", directoryHint: .isDirectory)
    }
}

enum PhononModelStoreError: LocalizedError {
    case invalidURL
    case invalidResponse
    case integrityFailure(String)
    case cacheUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The pinned Phonon-2 model URL is invalid."
        case .invalidResponse:
            "The Phonon-2 model download returned an invalid response."
        case .integrityFailure(let path):
            "The downloaded Phonon-2 file \(path) failed its size or SHA-256 check."
        case .cacheUnavailable:
            "The Talkies model folder is unavailable."
        }
    }
}
