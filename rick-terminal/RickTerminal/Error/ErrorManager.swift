import Foundation
import SwiftUI

/// Centralized error handling and logging manager
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    @Published private(set) var activeError: ErrorPresentation?
    @Published private(set) var recentErrors: [ErrorContext] = []

    private let maxRecentErrors = 100
    private let logQueue = DispatchQueue(label: "com.rick.terminal.error.log", qos: .utility)
    private var logFileHandle: FileHandle?
    private let logFileURL: URL

    private init() {
        // Set up log file in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("RickTerminal", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        logFileURL = appDir.appendingPathComponent("errors.log")

        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        // Open file handle for appending
        logFileHandle = try? FileHandle(forWritingTo: logFileURL)
        logFileHandle?.seekToEndOfFile()
    }

    deinit {
        try? logFileHandle?.close()
    }

    // MARK: - Error Handling

    /// Handle an error with full context
    func handle(
        _ error: RTError,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        sessionId: UUID? = nil,
        additionalInfo: [String: String] = [:],
        presentToUser: Bool = true
    ) {
        let context = ErrorContext(
            error: error,
            file: file,
            function: function,
            line: line,
            sessionId: sessionId,
            additionalInfo: additionalInfo
        )

        // Log to file
        if error.shouldLog {
            log(context)
        }

        // Add to recent errors
        DispatchQueue.main.async {
            self.recentErrors.insert(context, at: 0)
            if self.recentErrors.count > self.maxRecentErrors {
                self.recentErrors.removeLast()
            }
        }

        // Present to user if requested
        if presentToUser {
            present(error: error)
        }

        // Log to console in debug mode
        #if DEBUG
        print("🔴 RTError: \(context.logFormat)")
        #endif
    }

    /// Handle a Swift Error by wrapping it in RTError
    func handle(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        sessionId: UUID? = nil,
        additionalInfo: [String: String] = [:],
        presentToUser: Bool = true
    ) {
        let rtError: RTError
        if let rtErr = error as? RTError {
            rtError = rtErr
        } else {
            rtError = .unknown(error)
        }

        handle(
            rtError,
            file: file,
            function: function,
            line: line,
            sessionId: sessionId,
            additionalInfo: additionalInfo,
            presentToUser: presentToUser
        )
    }

    /// Present error to user with native alert
    func present(error: RTError) {
        DispatchQueue.main.async {
            self.activeError = ErrorPresentation(error: error)
        }
    }

    /// Dismiss the active error
    func dismissError() {
        DispatchQueue.main.async {
            self.activeError = nil
        }
    }

    // MARK: - Logging

    /// Log error context to file
    private func log(_ context: ErrorContext) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            let logEntry = context.logFormat + "\n"

            if let data = logEntry.data(using: .utf8) {
                self.logFileHandle?.write(data)
            }
        }
    }

    /// Get the error log file path
    func getLogFilePath() -> String {
        return logFileURL.path
    }

    /// Open error log in default text editor
    func openErrorLog() {
        NSWorkspace.shared.open(logFileURL)
    }

    /// Clear error log
    func clearErrorLog() {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            try? self.logFileHandle?.close()
            try? "".write(to: self.logFileURL, atomically: true, encoding: .utf8)
            self.logFileHandle = try? FileHandle(forWritingTo: self.logFileURL)
            self.logFileHandle?.seekToEndOfFile()

            DispatchQueue.main.async {
                self.recentErrors.removeAll()
            }
        }
    }

    /// Get recent error log entries as string
    func getRecentErrorLog(limit: Int = 50) -> String {
        let errors = Array(recentErrors.prefix(limit))
        return errors.map { $0.logFormat }.joined(separator: "\n---\n\n")
    }
}

/// Error presentation model for UI
struct ErrorPresentation: Identifiable {
    let id = UUID()
    let error: RTError
    let timestamp = Date()

    var title: String {
        switch error.severity {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical Error"
        }
    }
}
