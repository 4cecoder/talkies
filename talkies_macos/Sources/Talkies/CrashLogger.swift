import Foundation
import AppKit

struct CrashLogger {
    static let shared = CrashLogger()
    
    /// Sets up the global exception handler to catch uncaught exceptions.
    func setup() {
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.shared.log(exception: exception)
        }
    }
    
    /// Logs an exception to a file on disk.
    func log(exception: NSException) {
        let name = exception.name.rawValue
        let reason = exception.reason ?? "Unknown reason"
        let stackSymbols = exception.callStackSymbols.joined(separator: "\n")
        
        let report = """
        🚨 CRASH REPORT - \(Date())
        -------------------------------------------
        Name: \(name)
        Reason: \(reason)
        
        Stack Trace:
        \(stackSymbols)
        -------------------------------------------
        """
        
        // Print to console for immediate debugging
        print(report)
        
        // Save to Disk
        let filename = "crash-\(Date().timeIntervalSince1970).log"
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsDir.appendingPathComponent(filename)
            
            do {
                try report.write(to: fileURL, atomically: true, encoding: .utf8)
                print("✅ Crash log saved to: \(fileURL.path)")
            } catch {
                print("❌ Failed to save crash log: \(error)")
            }
        }
    }
}
