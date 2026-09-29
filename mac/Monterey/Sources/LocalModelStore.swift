import CryptoKit
import Foundation

actor LocalModelStore {
    private static let whisperModelRevision = "5359861c739e955e79d9a303bcbc70fb988958b1"

    enum Model: String {
        case whisperBase = "ggml-base.bin"
        case whisperTiny = "ggml-tiny.bin"
        case s1Mini = "s1-mini-q4_k_m.gguf"
    }

    private let session: URLSession
    private let directory: URL

    init(session: URLSession = .shared) throws {
        self.session = session
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ModelStoreError.storageUnavailable
        }
        directory = applicationSupport.appendingPathComponent("Talkies-Monterey/Models", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func ensure(_ model: Model) async throws -> URL {
        let destination = directory.appendingPathComponent(model.rawValue)
        if try Self.isVerified(destination, model: model) {
            if model == .s1Mini {
                try await ensureModelNotice("LICENSE")
                try await ensureModelNotice("NOTICE")
            }
            return destination
        }

        let url = try Self.downloadURL(for: model)
        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (temporaryURL, response) = try await session.download(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw ModelStoreError.downloadFailed(model.rawValue)
        }
        guard try Self.isVerified(temporaryURL, model: model) else {
            throw ModelStoreError.integrityFailed(model.rawValue)
        }

        let partial = destination.appendingPathExtension("partial")
        try? FileManager.default.removeItem(at: partial)
        try FileManager.default.moveItem(at: temporaryURL, to: partial)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: partial, to: destination)
        if model == .s1Mini {
            try await ensureModelNotice("LICENSE")
            try await ensureModelNotice("NOTICE")
        }
        return destination
    }

    private func ensureModelNotice(_ name: String) async throws {
        let destination = directory.appendingPathComponent("s1-mini-\(name)")
        if let values = try? destination.resourceValues(forKeys: [.fileSizeKey]),
           (values.fileSize ?? 0) > 0 { return }
        guard let url = URL(string: "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/34add00a48a2e5d24e5a4ee5405a99620a3a240c/\(name)?download=true") else {
            throw ModelStoreError.invalidURL
        }
        let (temporaryURL, response) = try await session.download(from: url)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let size = try? temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else {
            throw ModelStoreError.downloadFailed(name)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private static func downloadURL(for model: Model) throws -> URL {
        switch model {
        case .whisperBase:
            guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/\(whisperModelRevision)/ggml-base.bin?download=true") else {
                throw ModelStoreError.invalidURL
            }
            return url
        case .whisperTiny:
            guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/\(whisperModelRevision)/ggml-tiny.bin?download=true") else {
                throw ModelStoreError.invalidURL
            }
            return url
        case .s1Mini:
            guard let url = URL(string: "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/34add00a48a2e5d24e5a4ee5405a99620a3a240c/s1-mini-q4_k_m.gguf?download=true") else {
                throw ModelStoreError.invalidURL
            }
            return url
        }
    }

    private static func isVerified(_ url: URL, model: Model) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let expectedSize: Int
        let expectedSHA256: String
        switch model {
        case .whisperBase:
            expectedSize = 147_951_465
            expectedSHA256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
        case .whisperTiny:
            expectedSize = 77_691_713
            expectedSHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
        case .s1Mini:
            expectedSize = 484_219_808
            expectedSHA256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634"
        }
        guard values.fileSize == expectedSize else { return false }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return digest == expectedSHA256
    }

    enum ModelStoreError: LocalizedError {
        case storageUnavailable
        case invalidURL
        case downloadFailed(String)
        case integrityFailed(String)

        var errorDescription: String? {
            switch self {
            case .storageUnavailable:
                return "Talkies could not find a local models folder."
            case .invalidURL:
                return "The model download address is invalid."
            case .downloadFailed(let name):
                return "Could not download \(name). Check your connection and try again."
            case .integrityFailed(let name):
                return "The downloaded \(name) did not pass its integrity check."
            }
        }
    }
}
