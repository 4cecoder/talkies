import XCTest
@testable import TalkiesCore

final class ExporterTests: XCTestCase {

    // MARK: - Test Data

    var sampleSegments: [TranscriptSegment]!

    override func setUp() {
        super.setUp()
        sampleSegments = [
            TranscriptSegment(
                timestamp: "00:00:00",
                text: "Hello, this is the first segment.",
                start: 0.0,
                end: 2.5
            ),
            TranscriptSegment(
                timestamp: "00:00:03",
                text: "This is the second segment.",
                start: 3.0,
                end: 5.8
            ),
            TranscriptSegment(
                timestamp: "00:00:06",
                text: "And this is the third segment.",
                start: 6.2,
                end: 9.1
            )
        ]
    }

    override func tearDown() {
        sampleSegments = nil
        super.tearDown()
    }

    // MARK: - exportVTT tests

    func testExportVTT_EmptyArray() {
        let result = exportVTT(segments: [])
        XCTAssertEqual(result, "WEBVTT\n\n")
    }

    func testExportVTT_SingleSegment() {
        let segments = [
            TranscriptSegment(
                timestamp: "00:00:00",
                text: "Single segment test.",
                start: 1.0,
                end: 3.5
            )
        ]
        let result = exportVTT(segments: segments)

        XCTAssertTrue(result.hasPrefix("WEBVTT\n\n"))
        XCTAssertTrue(result.contains("1\n"))
        XCTAssertTrue(result.contains("00:00:01.000 --> 00:00:03.500"))
        XCTAssertTrue(result.contains("Single segment test."))
    }

    func testExportVTT_MultipleSegments() {
        let result = exportVTT(segments: sampleSegments)

        XCTAssertTrue(result.hasPrefix("WEBVTT\n\n"))

        // Check first segment
        XCTAssertTrue(result.contains("1\n"))
        XCTAssertTrue(result.contains("00:00:00.000 --> 00:00:02.500"))
        XCTAssertTrue(result.contains("Hello, this is the first segment."))

        // Check second segment
        XCTAssertTrue(result.contains("2\n"))
        XCTAssertTrue(result.contains("00:00:03.000 --> 00:00:05.800"))
        XCTAssertTrue(result.contains("This is the second segment."))

        // Check third segment
        XCTAssertTrue(result.contains("3\n"))
        XCTAssertTrue(result.contains("00:00:06.200 --> 00:00:09.100"))
        XCTAssertTrue(result.contains("And this is the third segment."))
    }

    func testExportVTT_UsesTimestampFormat() {
        let result = exportVTT(segments: sampleSegments)
        // VTT uses period for milliseconds
        XCTAssertTrue(result.contains(".000"))
        XCTAssertTrue(result.contains(".500"))
    }

    // MARK: - exportSRT tests

    func testExportSRT_EmptyArray() {
        let result = exportSRT(segments: [])
        XCTAssertEqual(result, "")
    }

    func testExportSRT_SingleSegment() {
        let segments = [
            TranscriptSegment(
                timestamp: "00:00:00",
                text: "Single SRT segment.",
                start: 2.0,
                end: 4.5
            )
        ]
        let result = exportSRT(segments: segments)

        XCTAssertTrue(result.contains("1\n"))
        XCTAssertTrue(result.contains("00:00:02,000 --> 00:00:04,500"))
        XCTAssertTrue(result.contains("Single SRT segment."))
    }

    func testExportSRT_MultipleSegments() {
        let result = exportSRT(segments: sampleSegments)

        // Check first segment
        XCTAssertTrue(result.contains("1\n"))
        XCTAssertTrue(result.contains("00:00:00,000 --> 00:00:02,500"))
        XCTAssertTrue(result.contains("Hello, this is the first segment."))

        // Check second segment
        XCTAssertTrue(result.contains("2\n"))
        XCTAssertTrue(result.contains("00:00:03,000 --> 00:00:05,800"))
        XCTAssertTrue(result.contains("This is the second segment."))

        // Check third segment
        XCTAssertTrue(result.contains("3\n"))
        XCTAssertTrue(result.contains("00:00:06,200 --> 00:00:09,100"))
        XCTAssertTrue(result.contains("And this is the third segment."))
    }

    func testExportSRT_UsesCommaFormat() {
        let result = exportSRT(segments: sampleSegments)
        // SRT uses comma for milliseconds, not period
        XCTAssertTrue(result.contains(",000"))
        XCTAssertTrue(result.contains(",500"))
        // Make sure periods aren't used in timestamps
        let lines = result.split(separator: "\n")
        for line in lines {
            if line.contains("-->") {
                // Timestamp lines should use commas
                let timestampPart = String(line)
                let timeComponents = timestampPart.components(separatedBy: " --> ")
                for component in timeComponents {
                    if component.contains(":") {
                        XCTAssertTrue(component.contains(",") || !component.contains("."))
                    }
                }
            }
        }
    }

    // MARK: - exportTXT tests

    func testExportTXT_EmptyArray() {
        let result = exportTXT(segments: [])
        XCTAssertEqual(result, "")
    }

    func testExportTXT_SingleSegment() {
        let segments = [
            TranscriptSegment(
                timestamp: "00:00:05",
                text: "Plain text segment.",
                start: 5.0,
                end: 7.0
            )
        ]
        let result = exportTXT(segments: segments)

        XCTAssertEqual(result, "[00:00:05] Plain text segment.\n")
    }

    func testExportTXT_MultipleSegments() {
        let result = exportTXT(segments: sampleSegments)

        let expectedLines = [
            "[00:00:00] Hello, this is the first segment.",
            "[00:00:03] This is the second segment.",
            "[00:00:06] And this is the third segment."
        ]

        for line in expectedLines {
            XCTAssertTrue(result.contains(line))
        }
    }

    func testExportTXT_Format() {
        let segments = [
            TranscriptSegment(
                timestamp: "00:01:23",
                text: "Test message.",
                start: 83.0,
                end: 85.0
            )
        ]
        let result = exportTXT(segments: segments)

        XCTAssertEqual(result, "[00:01:23] Test message.\n")
    }

    func testExportTXT_PreservesOrder() {
        let result = exportTXT(segments: sampleSegments)
        let lines = result.split(separator: "\n").map { String($0) }

        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].contains("first segment"))
        XCTAssertTrue(lines[1].contains("second segment"))
        XCTAssertTrue(lines[2].contains("third segment"))
    }
}
