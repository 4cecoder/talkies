import XCTest
@testable import TalkiesCore

final class ModelTests: XCTestCase {

    // MARK: - TranscriptSegment Init tests

    func testTranscriptSegment_DefaultInit() {
        let segment = TranscriptSegment(
            timestamp: "00:01:23",
            text: "Test text",
            start: 83.0,
            end: 85.5
        )

        XCTAssertNotNil(segment.id)
        XCTAssertEqual(segment.timestamp, "00:01:23")
        XCTAssertEqual(segment.text, "Test text")
        XCTAssertEqual(segment.start, 83.0)
        XCTAssertEqual(segment.end, 85.5)
    }

    func testTranscriptSegment_InitWithCustomID() {
        let customID = UUID()
        let segment = TranscriptSegment(
            id: customID,
            timestamp: "00:00:00",
            text: "Custom ID test",
            start: 0.0,
            end: 1.0
        )

        XCTAssertEqual(segment.id, customID)
        XCTAssertEqual(segment.timestamp, "00:00:00")
        XCTAssertEqual(segment.text, "Custom ID test")
        XCTAssertEqual(segment.start, 0.0)
        XCTAssertEqual(segment.end, 1.0)
    }

    func testTranscriptSegment_EmptyText() {
        let segment = TranscriptSegment(
            timestamp: "00:00:00",
            text: "",
            start: 0.0,
            end: 0.0
        )

        XCTAssertEqual(segment.text, "")
    }

    // MARK: - TranscriptSegment Codable tests

    func testTranscriptSegment_Encoding() throws {
        let segment = TranscriptSegment(
            timestamp: "00:01:30",
            text: "Encoding test",
            start: 90.0,
            end: 92.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(segment)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["timestamp"] as? String, "00:01:30")
        XCTAssertEqual(json?["text"] as? String, "Encoding test")
        XCTAssertEqual(json?["start"] as? Double, 90.0)
        XCTAssertEqual(json?["end"] as? Double, 92.5)
        // ID should not be encoded
        XCTAssertNil(json?["id"])
    }

    func testTranscriptSegment_Decoding() throws {
        let json = """
        {
            "timestamp": "00:02:15",
            "text": "Decoding test",
            "start": 135.0,
            "end": 138.5
        }
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let segment = try decoder.decode(TranscriptSegment.self, from: data)

        XCTAssertNotNil(segment.id) // ID should be generated
        XCTAssertEqual(segment.timestamp, "00:02:15")
        XCTAssertEqual(segment.text, "Decoding test")
        XCTAssertEqual(segment.start, 135.0)
        XCTAssertEqual(segment.end, 138.5)
    }

    func testTranscriptSegment_RoundTrip() throws {
        let original = TranscriptSegment(
            timestamp: "00:03:45",
            text: "Round trip test",
            start: 225.0,
            end: 230.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TranscriptSegment.self, from: data)

        // IDs won't match because decoding creates a new UUID
        XCTAssertEqual(decoded.timestamp, original.timestamp)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.start, original.start)
        XCTAssertEqual(decoded.end, original.end)
    }

    func testTranscriptSegment_DecodingArray() throws {
        let json = """
        [
            {
                "timestamp": "00:00:00",
                "text": "First segment",
                "start": 0.0,
                "end": 2.5
            },
            {
                "timestamp": "00:00:03",
                "text": "Second segment",
                "start": 3.0,
                "end": 5.0
            }
        ]
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let segments = try decoder.decode([TranscriptSegment].self, from: data)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "First segment")
        XCTAssertEqual(segments[1].text, "Second segment")
    }

    // MARK: - TranscriptSegment Equatable tests

    func testTranscriptSegment_Equality_SameValues() {
        let id = UUID()
        let segment1 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )

        XCTAssertEqual(segment1, segment2)
    }

    func testTranscriptSegment_Equality_DifferentID() {
        let segment1 = TranscriptSegment(
            id: UUID(),
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            id: UUID(),
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    func testTranscriptSegment_Equality_DifferentText() {
        let id = UUID()
        let segment1 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "First",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Second",
            start: 0.0,
            end: 1.0
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    func testTranscriptSegment_Equality_DifferentTimestamp() {
        let id = UUID()
        let segment1 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            id: id,
            timestamp: "00:00:05",
            text: "Test",
            start: 0.0,
            end: 1.0
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    func testTranscriptSegment_Equality_DifferentStartTime() {
        let id = UUID()
        let segment1 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 5.0,
            end: 1.0
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    func testTranscriptSegment_Equality_DifferentEndTime() {
        let id = UUID()
        let segment1 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            id: id,
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 5.0
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    // MARK: - TranscriptSegment Identifiable tests

    func testTranscriptSegment_Identifiable() {
        let segment1 = TranscriptSegment(
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )
        let segment2 = TranscriptSegment(
            timestamp: "00:00:00",
            text: "Test",
            start: 0.0,
            end: 1.0
        )

        // Each segment should have a unique ID
        XCTAssertNotEqual(segment1.id, segment2.id)
    }

    // MARK: - TranscriptSegment Edge Cases

    func testTranscriptSegment_NegativeTime() {
        let segment = TranscriptSegment(
            timestamp: "00:00:00",
            text: "Test",
            start: -1.0,
            end: 0.0
        )

        XCTAssertEqual(segment.start, -1.0)
        XCTAssertEqual(segment.end, 0.0)
    }

    func testTranscriptSegment_VeryLargeTime() {
        let segment = TranscriptSegment(
            timestamp: "99:59:59",
            text: "Test",
            start: 359999.0,
            end: 360000.0
        )

        XCTAssertEqual(segment.start, 359999.0)
        XCTAssertEqual(segment.end, 360000.0)
    }

    func testTranscriptSegment_SpecialCharactersInText() {
        let specialText = "Test with special chars: éñü 中文 🎉"
        let segment = TranscriptSegment(
            timestamp: "00:00:00",
            text: specialText,
            start: 0.0,
            end: 1.0
        )

        XCTAssertEqual(segment.text, specialText)
    }
}
