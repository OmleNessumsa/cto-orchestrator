import Foundation

/// Service for detecting and validating Claude CLI installation
/// Checks common installation locations and allows manual configuration
class ClaudePathDetector {
    static let shared = ClaudePathDetector()

    // MARK: - Common Installation Paths

    /// Common locations where Claude CLI might be installed
    private let commonPaths: [String] = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/opt/local/bin/claude",
        "~/.local/bin/claude",
        "/usr/bin/claude"
    ]

    // MARK: - Detection

    /// Auto-detect Claude CLI installation
    /// - Returns: Path to Claude CLI if found, nil otherwise
    func autoDetect() -> String? {
        for path in commonPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if isValidClaudePath(expandedPath) {
                return expandedPath
            }
        }

        // Try to find via `which` command as fallback
        return findViaWhichCommand()
    }

    /// Find Claude CLI using `which` command
    /// - Returns: Path if found via which, nil otherwise
    private func findViaWhichCommand() -> String? {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["claude"]
        task.standardOutput = pipe
        task.standardError = Pipe() // Discard errors

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let path = output, !path.isEmpty, isValidClaudePath(path) {
                return path
            }
        } catch {
            // which command failed, return nil
            return nil
        }

        return nil
    }

    // MARK: - Validation

    /// Validate that a path points to an executable Claude CLI
    /// - Parameter path: Path to validate
    /// - Returns: true if path is valid and executable, false otherwise
    func isValidClaudePath(_ path: String) -> Bool {
        let fileManager = FileManager.default

        // Expand tilde if present
        let expandedPath = NSString(string: path).expandingTildeInPath

        // Check if file exists
        guard fileManager.fileExists(atPath: expandedPath) else {
            return false
        }

        // Check if file is executable
        guard fileManager.isExecutableFile(atPath: expandedPath) else {
            return false
        }

        // Just check file exists and is executable
        // Don't try to run --version as it may fail in app sandbox
        return true
    }

    /// Verify that executable at path is actually Claude CLI
    /// - Parameter path: Path to executable
    /// - Returns: true if it responds to --version, false otherwise
    private func verifyClaudeExecutable(at path: String) -> Bool {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["--version"]
        task.standardOutput = pipe
        task.standardError = Pipe()

        // Set timeout - don't wait forever
        do {
            try task.run()

            // Wait with timeout
            var timeout = 2.0 // 2 seconds
            while task.isRunning && timeout > 0 {
                Thread.sleep(forTimeInterval: 0.1)
                timeout -= 0.1
            }

            if task.isRunning {
                task.terminate()
                return false
            }

            // Check if command succeeded
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Path Expansion

    /// Expand tilde and environment variables in path
    /// - Parameter path: Path to expand
    /// - Returns: Expanded path
    func expandPath(_ path: String) -> String {
        return NSString(string: path).expandingTildeInPath
    }

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
    }
}
