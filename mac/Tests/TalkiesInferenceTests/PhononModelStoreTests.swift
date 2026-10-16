import XCTest
@testable import TalkiesInference

final class PhononModelStoreTests: XCTestCase {
    func testEveryArtifactIsPinnedWithSizeAndHash() {
        XCTAssertEqual(PhononModelStore.revision.count, 40)
        for artifact in PhononModelStore.artifacts {
            XCTAssertGreaterThan(artifact.size, 0, artifact.path)
            XCTAssertEqual(artifact.sha256.count, 64, artifact.path)
        }
        let paths = Set(PhononModelStore.artifacts.map(\.path))
        XCTAssertTrue(paths.isSuperset(of: ["manifest.json", "decoder.bin", "NOTICE", "LICENSE-WEIGHTS-CC-BY-4.0.txt"]))
    }

    func testDownloadURLUsesPinnedRevision() throws {
        let artifact = try XCTUnwrap(PhononModelStore.artifacts.first)
        let url = try XCTUnwrap(PhononModelStore.downloadURL(for: artifact))
        XCTAssertEqual(url.host, "huggingface.co")
        XCTAssertTrue(url.path.contains("/resolve/\(PhononModelStore.revision)/"))
    }

    func testIncompleteBundleIsNotInstalled() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{}".utf8).write(to: directory.appending(path: "manifest.json"))
        let installed = try await PhononModelStore(directory: directory).installedBundle()
        XCTAssertNil(installed)
    }

    func testTamperedFileFailsVerification() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("x".utf8).write(to: url)
        let artifact = PhononModelStore.Artifact(path: "x", size: 1, sha256: String(repeating: "0", count: 64))
        XCTAssertFalse(try PhononModelStore.isValid(url, artifact: artifact))
    }

    func testSegmentsFallBackToFullTextAndDropBlanks() {
        XCTAssertTrue(PhononRecognizer.segments(from: [], fallbackText: "  ", duration: 2).isEmpty)
        let fallback = PhononRecognizer.segments(from: [], fallbackText: " hello ", duration: 2)
        XCTAssertEqual(fallback.map(\.text), ["hello"])
        XCTAssertEqual(fallback.first?.end, 2)
    }
}
