import Foundation

/// Comprehensive error types for Rick Terminal
/// Provides categorized errors with user-friendly messages and recovery actions
enum RTError: Error {
    // MARK: - Claude CLI Errors
    case claudeNotFound
    case claudeNotConfigured
    case claudeInvalidPath(String)
    case claudeLaunchFailed(Error)
    case claudeNotRunning
    case claudeAlreadyRunning

    // MARK: - File Operation Errors
    case fileNotFound(String)
    case filePermissionDenied(String)
    case fileReadFailed(String, Error)
    case fileWriteFailed(String, Error)
    case directoryCreationFailed(String, Error)
    case invalidPath(String)

    // MARK: - Git Operation Errors
    case gitNotInstalled
    case gitNotRepository
    case gitCommandFailed(String, Error)
    case gitMergeFailed(String)
    case gitCommitFailed(Error)

    // MARK: - Shell Session Errors
    case sessionNotFound
    case sessionCreationFailed(Error)
    case sessionAlreadyRunning
    case ptyCreationFailed
    case processSpawnFailed
    case sessionSaveFailed
    case sessionRestoreFailed

    // MARK: - Network Errors
    case networkUnavailable
    case apiRequestFailed(Error)
    case timeoutError

    // MARK: - General Errors
    case invalidConfiguration(String)
    case operationCancelled
    case unknown(Error)

    // MARK: - User-Friendly Messages

    /// The user-facing error message
    var userMessage: String {
        switch self {
        // Claude CLI Errors
        case .claudeNotFound:
            return "Claude CLI not found on your system"
        case .claudeNotConfigured:
            return "Claude CLI path not configured"
        case .claudeInvalidPath(let path):
            return "Invalid Claude CLI path: \(path)"
        case .claudeLaunchFailed:
            return "Failed to launch Claude CLI"
        case .claudeNotRunning:
            return "Claude CLI is not running"
        case .claudeAlreadyRunning:
            return "Claude CLI is already running"

        // File Operation Errors
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .filePermissionDenied(let path):
            return "Permission denied: \(path)"
        case .fileReadFailed(let path, _):
            return "Failed to read file: \(path)"
        case .fileWriteFailed(let path, _):
            return "Failed to write file: \(path)"
        case .directoryCreationFailed(let path, _):
            return "Failed to create directory: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"

        // Git Operation Errors
        case .gitNotInstalled:
            return "Git is not installed on your system"
        case .gitNotRepository:
            return "Not a git repository"
        case .gitCommandFailed(let command, _):
            return "Git command failed: \(command)"
        case .gitMergeFailed(let branch):
            return "Failed to merge branch: \(branch)"
        case .gitCommitFailed:
            return "Failed to create git commit"

        // Shell Session Errors
        case .sessionNotFound:
            return "Shell session not found"
        case .sessionCreationFailed:
            return "Failed to create shell session"
        case .sessionAlreadyRunning:
            return "Session is already running"
        case .ptyCreationFailed:
            return "Failed to create pseudo-terminal"
        case .processSpawnFailed:
            return "Failed to spawn shell process"
        case .sessionSaveFailed:
            return "Failed to save session"
        case .sessionRestoreFailed:
            return "Failed to restore session"

        // Network Errors
        case .networkUnavailable:
            return "Network connection unavailable"
        case .apiRequestFailed:
            return "API request failed"
        case .timeoutError:
            return "Operation timed out"

        // General Errors
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .operationCancelled:
            return "Operation cancelled"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }

    /// Detailed technical description for logging
    var technicalMessage: String {
        switch self {
        case .claudeLaunchFailed(let error),
             .fileReadFailed(_, let error),
             .fileWriteFailed(_, let error),
             .directoryCreationFailed(_, let error),
             .gitCommandFailed(_, let error),
             .sessionCreationFailed(let error),
             .apiRequestFailed(let error),
             .gitCommitFailed(let error),
             .unknown(let error):
            return "\(userMessage) - \(error.localizedDescription)"
        default:
            return userMessage
        }
    }

    /// Suggested recovery actions for the user
    var recoveryActions: [String] {
        switch self {
        // Claude CLI Errors
        case .claudeNotFound, .claudeNotConfigured:
            return [
                "Install Claude CLI: npm install -g @anthropic-ai/claude-cli",
                "Or manually configure the path in Settings"
            ]
        case .claudeInvalidPath:
            return [
                "Check the Claude CLI path in Settings",
                "Try running 'which claude' in terminal to find the correct path"
            ]
        case .claudeLaunchFailed:
            return [
                "Verify Claude CLI is installed correctly",
                "Check terminal permissions",
                "Try restarting the application"
            ]
        case .claudeNotRunning:
            return [
                "Launch Claude CLI using Cmd+Shift+C",
                "Or use the Claude menu"
            ]
        case .claudeAlreadyRunning:
            return [
                "Claude CLI is already active",
                "Use the existing session"
            ]

        // File Operation Errors
        case .fileNotFound:
            return [
                "Check that the file exists",
                "Verify the file path is correct"
            ]
        case .filePermissionDenied:
            return [
                "Check file permissions",
                "You may need to grant access in System Settings > Privacy & Security"
            ]
        case .fileReadFailed, .fileWriteFailed:
            return [
                "Check file permissions",
                "Ensure the file is not in use by another application",
                "Verify you have read/write access"
            ]
        case .directoryCreationFailed:
            return [
                "Check parent directory permissions",
                "Verify the path is valid"
            ]
        case .invalidPath:
            return [
                "Check the file path is correct",
                "Ensure the path exists"
            ]

        // Git Operation Errors
        case .gitNotInstalled:
            return [
                "Install Git from git-scm.com",
                "Or install via Homebrew: brew install git"
            ]
        case .gitNotRepository:
            return [
                "Navigate to a git repository",
                "Or initialize a new repository: git init"
            ]
        case .gitCommandFailed, .gitMergeFailed, .gitCommitFailed:
            return [
                "Check git status for conflicts",
                "Review the command output for details",
                "Try resolving conflicts manually"
            ]

        // Shell Session Errors
        case .sessionNotFound:
            return [
                "Create a new terminal session",
                "Restart the application"
            ]
        case .sessionCreationFailed, .ptyCreationFailed, .processSpawnFailed:
            return [
                "Try restarting the application",
                "Check system resources",
                "Verify terminal permissions"
            ]
        case .sessionAlreadyRunning:
            return [
                "Use the existing session",
                "Or close the current session first"
            ]
        case .sessionSaveFailed:
            return [
                "Check disk space",
                "Verify write permissions for Application Support directory"
            ]
        case .sessionRestoreFailed:
            return [
                "Start a new session instead",
                "Check if the saved session file is corrupted"
            ]

        // Network Errors
        case .networkUnavailable:
            return [
                "Check your internet connection",
                "Verify network settings"
            ]
        case .apiRequestFailed:
            return [
                "Check your internet connection",
                "Try again in a moment",
                "Verify API credentials if required"
            ]
        case .timeoutError:
            return [
                "Try again",
                "Check your internet connection speed"
            ]

        // General Errors
        case .invalidConfiguration:
            return [
                "Check application settings",
                "Reset to default configuration"
            ]
        case .operationCancelled:
            return []
        case .unknown:
            return [
                "Try restarting the application",
                "Check the error log for details"
            ]
        }
    }

    /// Whether this error should be logged to file
    var shouldLog: Bool {
        switch self {
        case .operationCancelled:
            return false
        default:
            return true
        }
    }

    /// Severity level for logging and UI presentation
    var severity: ErrorSeverity {
        switch self {
        case .claudeNotFound, .claudeNotConfigured, .gitNotInstalled:
            return .warning
        case .operationCancelled:
            return .info
        case .fileNotFound, .invalidPath:
            return .warning
        case .networkUnavailable, .timeoutError:
            return .warning
        default:
            return .error
        }
    }
}

/// Error severity levels
enum ErrorSeverity {
    case info
    case warning
    case error
    case critical

    var icon: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
}

/// Error context for enhanced logging
struct ErrorContext {
    let error: RTError
    let timestamp: Date
    let file: String
    let function: String
    let line: Int
    let sessionId: UUID?
    let additionalInfo: [String: String]

    init(
        error: RTError,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        sessionId: UUID? = nil,
        additionalInfo: [String: String] = [:]
    ) {
        self.error = error
        self.timestamp = Date()
        self.file = file
        self.function = function
        self.line = line
        self.sessionId = sessionId
        self.additionalInfo = additionalInfo
    }

    /// Format for logging
    var logFormat: String {
        let fileName = (file as NSString).lastPathComponent
        var log = "[\(timestamp.formatted())] [\(error.severity)] \(fileName):\(line) \(function)\n"
        log += "Error: \(error.technicalMessage)\n"

        if let sessionId = sessionId {
            log += "Session: \(sessionId)\n"
        }

        if !additionalInfo.isEmpty {
            log += "Additional Info:\n"
            for (key, value) in additionalInfo {
                log += "  \(key): \(value)\n"
            }
        }

        return log
    }
}

// MARK: - Identifiable Conformance

extension RTError: Identifiable {
    var id: String {
        return userMessage
    }
}
