import Foundation

/// Writes bounded exception diagnostics to local application support storage.
/// This store has no networking or app-state dependencies by design.
public struct LocalCrashDiagnostics {
    public static let maximumReportBytes = 32 * 1024
    public static let maximumReports = 5

    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public static func defaultStore(fileManager: FileManager = .default) -> LocalCrashDiagnostics? {
        guard let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return LocalCrashDiagnostics(
            directory: supportDirectory.appendingPathComponent("Talkies/Diagnostics", isDirectory: true),
            fileManager: fileManager
        )
    }

    public static func format(
        name: String,
        reason: String?,
        timestamp: Date,
        stackTrace: [String]
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let safeName = bounded(name, maximumBytes: 256)
        let safeReason = bounded(reason ?? "Unknown reason", maximumBytes: 4 * 1024)
        let safeStack = bounded(stackTrace.joined(separator: "\n"), maximumBytes: 24 * 1024)
        let report = """
        TALKIES LOCAL EXCEPTION REPORT
        Timestamp: \(formatter.string(from: timestamp))
        Name: \(safeName)
        Reason: \(safeReason)
        Stack trace:
        \(safeStack)
        """
        return bounded(report, maximumBytes: maximumReportBytes)
    }

    /// Persists one exception report and prunes older reports. Returns nil on
    /// filesystem errors so diagnostics can never interrupt normal app flow.
    @discardableResult
    public func write(name: String, reason: String?, timestamp: Date, stackTrace: [String]) -> URL? {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let report = Self.format(name: name, reason: reason, timestamp: timestamp, stackTrace: stackTrace)
            let filename = "crash-\(Int(timestamp.timeIntervalSince1970 * 1_000))-\(UUID().uuidString).log"
            let fileURL = directory.appendingPathComponent(filename, isDirectory: false)
            try Data(report.utf8).write(to: fileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            try rotateReports()
            return fileURL
        } catch {
            return nil
        }
    }

    private func rotateReports() throws {
        let reports = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("crash-") && $0.pathExtension == "log" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for oldReport in reports.dropFirst(Self.maximumReports) {
            try fileManager.removeItem(at: oldReport)
        }
    }

    private static func bounded(_ value: String, maximumBytes: Int) -> String {
        guard value.utf8.count > maximumBytes else { return value }
        let suffix = "\n[truncated]"
        let payloadLimit = max(0, maximumBytes - suffix.utf8.count)
        var result = ""
        for scalar in value.unicodeScalars {
            let next = result + String(scalar)
            guard next.utf8.count <= payloadLimit else { break }
            result = next
        }
        return result + suffix
    }
}
