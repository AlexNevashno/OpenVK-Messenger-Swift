import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public final class CrashLoggerService: @unchecked Sendable {
    public static let shared = CrashLoggerService()

    private let fileManager = FileManager.default
    private var logsDirectory: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("CrashLogs")
    }

    private init() {}

    public func install() {
        createLogsDirectoryIfNeeded()

        // 1. NSUncaughtExceptionHandler for Swift/Objective-C runtime exceptions
        NSSetUncaughtExceptionHandler { exception in
            CrashLoggerService.shared.handleUncaughtException(exception)
        }

        // 2. POSIX Signals for low-level memory/abort crashes
        setupSignalHandlers()

        print("DEBUG: [CrashLogger] Crash logging system successfully initialized.")
    }

    private func createLogsDirectoryIfNeeded() {
        guard let dir = logsDirectory else { return }
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    public func listCrashLogs() -> [URL] {
        guard let dir = logsDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" || $0.pathExtension == "txt" }
            .sorted { (u1, u2) -> Bool in
                let d1 = (try? u1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return d1 > d2
            }
    }

    public func readLatestCrashLog() -> String? {
        guard let latest = listCrashLogs().first else { return nil }
        return try? String(contentsOf: latest, encoding: .utf8)
    }

    private func handleUncaughtException(_ exception: NSException) {
        let name = exception.name.rawValue
        let reason = exception.reason ?? "Unknown reason"
        let callStack = exception.callStackSymbols.joined(separator: "\n")

        let report = buildCrashReport(
            type: "NSException: \(name)",
            reason: reason,
            callStack: callStack
        )
        writeReportToFile(report)
    }

    private func setupSignalHandlers() {
        let signals = [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP]
        for sig in signals {
            signal(sig) { signum in
                let symbols = Thread.callStackSymbols.joined(separator: "\n")
                let report = CrashLoggerService.shared.buildCrashReport(
                    type: "POSIX Signal \(signum)",
                    reason: CrashLoggerService.signalName(signum),
                    callStack: symbols
                )
                CrashLoggerService.shared.writeReportToFile(report)

                // Re-raise signal to let OS generate crashdump
                signal(signum, SIG_DFL)
                kill(getpid(), signum)
            }
        }
    }

    private static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT (Abort)"
        case SIGSEGV: return "SIGSEGV (Segmentation Fault)"
        case SIGBUS: return "SIGBUS (Bus Error)"
        case SIGILL: return "SIGILL (Illegal Instruction)"
        case SIGTRAP: return "SIGTRAP (Trace/BPT Trap)"
        default: return "Signal \(sig)"
        }
    }

    private func buildCrashReport(type: String, reason: String, callStack: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = formatter.string(from: Date())

        #if os(macOS)
        let osInfo = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #else
        let osInfo = "iOS \(UIDevice.current.systemVersion) (\(UIDevice.current.model))"
        #endif

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return """
        ================================================================
        OPENVK MESSENGER CRASH REPORT
        ================================================================
        Date: \(dateStr)
        OS: \(osInfo)
        App Version: \(appVersion) (\(buildNumber))
        Crash Type: \(type)
        Reason: \(reason)

        Thread Call Stack:
        \(callStack)
        ================================================================
        """
    }

    private func writeReportToFile(_ content: String) {
        createLogsDirectoryIfNeeded()
        guard let dir = logsDirectory else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "crash_\(formatter.string(from: Date())).log"
        let fileURL = dir.appendingPathComponent(fileName)

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("CRITICAL: Crash report saved to \(fileURL.path)")
    }
}
