import XCTest
@testable import TalkiesCore

final class FormatterTests: XCTestCase {

    // MARK: - formatTimestamp tests

    func testFormatTimestamp_Zero() {
        let result = formatTimestamp(time: 0.0)
        XCTAssertEqual(result, "00:00:00.000")
    }

    func testFormatTimestamp_OnlySeconds() {
        let result = formatTimestamp(time: 45.0)
        XCTAssertEqual(result, "00:00:45.000")
    }

    func testFormatTimestamp_WithMilliseconds() {
        let result = formatTimestamp(time: 12.345)
        XCTAssertEqual(result, "00:00:12.345")
    }

    func testFormatTimestamp_WithMinutes() {
        let result = formatTimestamp(time: 125.678)
        XCTAssertEqual(result, "00:02:05.678")
    }

    func testFormatTimestamp_WithHours() {
        let result = formatTimestamp(time: 3661.123)
        XCTAssertEqual(result, "01:01:01.123")
    }

    func testFormatTimestamp_LargeValue() {
        let result = formatTimestamp(time: 7384.999)
        XCTAssertEqual(result, "02:03:04.999")
    }

    // MARK: - formatSRTTime tests

    func testFormatSRTTime_Zero() {
        let result = formatSRTTime(time: 0.0)
        XCTAssertEqual(result, "00:00:00,000")
    }

    func testFormatSRTTime_OnlySeconds() {
        let result = formatSRTTime(time: 30.0)
        XCTAssertEqual(result, "00:00:30,000")
    }

    func testFormatSRTTime_WithMilliseconds() {
        let result = formatSRTTime(time: 5.567)
        XCTAssertEqual(result, "00:00:05,567")
    }

    func testFormatSRTTime_WithMinutes() {
        let result = formatSRTTime(time: 150.250)
        XCTAssertEqual(result, "00:02:30,250")
    }

    func testFormatSRTTime_WithHours() {
        let result = formatSRTTime(time: 3723.456)
        XCTAssertEqual(result, "01:02:03,456")
    }

    func testFormatSRTTime_CommaNotPeriod() {
        let result = formatSRTTime(time: 1.5)
        XCTAssertTrue(result.contains(","))
        XCTAssertFalse(result.contains("."))
    }

    // MARK: - formatDuration tests

    func testFormatDuration_Zero() {
        let result = formatDuration(seconds: 0)
        XCTAssertEqual(result, "00:00")
    }

    func testFormatDuration_OnlySeconds() {
        let result = formatDuration(seconds: 42)
        XCTAssertEqual(result, "00:42")
    }

    func testFormatDuration_OneMinute() {
        let result = formatDuration(seconds: 60)
        XCTAssertEqual(result, "01:00")
    }

    func testFormatDuration_MinutesAndSeconds() {
        let result = formatDuration(seconds: 125)
        XCTAssertEqual(result, "02:05")
    }

    func testFormatDuration_LargeValue() {
        let result = formatDuration(seconds: 599)
        XCTAssertEqual(result, "09:59")
    }

    func testFormatDuration_OverAnHour() {
        let result = formatDuration(seconds: 3661)
        XCTAssertEqual(result, "61:01")
    }

    func testFormatDuration_IgnoresMilliseconds() {
        let result = formatDuration(seconds: 30.999)
        XCTAssertEqual(result, "00:30")
    }
}
