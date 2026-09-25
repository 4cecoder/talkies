import Foundation
import AppKit
import TalkiesCore

struct CrashLogger {
    static let shared = CrashLogger()
    
    /// Sets up the global exception handler to catch uncaught exceptions.
    func setup() {
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.shared.log(exception: exception)
        }
    }
    
    /// Logs only exception metadata locally. Diagnostics are best-effort and
    /// never include app state, audio, or transcript content.
    func log(exception: NSException) {
        let timestamp = Date()
        _ = LocalCrashDiagnostics.defaultStore()?.write(
            name: exception.name.rawValue,
            reason: exception.reason,
            timestamp: timestamp,
            stackTrace: exception.callStackSymbols
        )
    }
}
