import Foundation
import XCTest
@testable import TalkiesCore

final class LocalCrashDiagnosticsTests: XCTestCase {
    func testFormatsOnlyExceptionMetadataWithStableTimestamp() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let report = LocalCrashDiagnostics.format(
            name: "NSInternalInconsistencyException",
            reason: "Unexpected state",
            timestamp: date,
            stackTrace: ["frame one", "frame two"]
        )

        XCTAssertTrue(report.contains("Timestamp: 2023-11-14T22:13:20.000Z"))
        XCTAssertTrue(report.contains("Name: NSInternalInconsistencyException"))
        XCTAssertTrue(report.contains("Reason: Unexpected state"))
        XCTAssertTrue(report.contains("frame one\nframe two"))
        XCTAssertLessThanOrEqual(report.utf8.count, LocalCrashDiagnostics.maximumReportBytes)
    }

    func testFormatBoundsUntrustedExceptionFields() {
        let report = LocalCrashDiagnostics.format(
            name: String(repeating: "N", count: 2_000),
            reason: String(repeating: "R", count: 100_000),
            timestamp: Date(timeIntervalSince1970: 0),
            stackTrace: [String(repeating: "S", count: 100_000)]
        )

        XCTAssertLessThanOrEqual(report.utf8.count, LocalCrashDiagnostics.maximumReportBytes)
        XCTAssertTrue(report.contains("[truncated]"))
    }

    func testWriteRotatesOldestReportsAndKeepsNewestFive() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TalkiesCrashDiagnosticsTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalCrashDiagnostics(directory: directory)
        let epoch = Date(timeIntervalSince1970: 1_700_000_000)

        for offset in 0..<7 {
            let result = store.write(
                name: "TestException",
                reason: "reason \(offset)",
                timestamp: epoch.addingTimeInterval(TimeInterval(offset)),
                stackTrace: ["frame \(offset)"]
            )
            XCTAssertNotNil(result)
        }

        let reports = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(reports.count, LocalCrashDiagnostics.maximumReports)
        let directoryPermissions = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(directoryPermissions?.intValue, 0o700)
        let reportText = try reports.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        XCTAssertTrue(reportText.contains("reason 6"))
        XCTAssertTrue(reportText.contains("reason 2"))
        XCTAssertFalse(reportText.contains("reason 0"))
        for report in reports {
            let data = try Data(contentsOf: report)
            XCTAssertLessThanOrEqual(data.count, LocalCrashDiagnostics.maximumReportBytes)
            let filePermissions = try FileManager.default.attributesOfItem(atPath: report.path)[.posixPermissions] as? NSNumber
            XCTAssertEqual(filePermissions?.intValue, 0o600)
        }
    }

    func testWriteFailureReturnsNilWithoutThrowing() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data().write(to: file)
        let store = LocalCrashDiagnostics(directory: file.appendingPathComponent("Diagnostics"))

        XCTAssertNil(store.write(name: "TestException", reason: nil, timestamp: Date(), stackTrace: []))
    }
}
