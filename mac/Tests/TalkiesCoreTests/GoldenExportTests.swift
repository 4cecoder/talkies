import Foundation
import XCTest
@testable import TalkiesCore

final class GoldenExportTests: XCTestCase {
    func testTranscriptExportsMatchSharedCrossPlatformGoldenFixture() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "linux/src/testdata/transcript-export-golden.json")
        let fixture = try JSONDecoder().decode(ExportGoldenFixture.self, from: Data(contentsOf: fixtureURL))
        let segments = fixture.segments.map {
            TranscriptSegment(timestamp: $0.timestamp, text: $0.text, start: $0.start, end: $0.end)
        }

        XCTAssertEqual(exportTXT(segments: segments), fixture.txt)
        XCTAssertEqual(exportVTT(segments: segments), fixture.vtt)
        XCTAssertEqual(exportSRT(segments: segments), fixture.srt)
    }
}

private struct ExportGoldenFixture: Decodable {
    let segments: [Segment]
    let txt: String
    let vtt: String
    let srt: String

    struct Segment: Decodable {
        let timestamp: String
        let text: String
        let start: Double
        let end: Double
    }
}
