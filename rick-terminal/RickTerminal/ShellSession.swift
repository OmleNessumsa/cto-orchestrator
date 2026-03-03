import Foundation

/// Represents a single shell session with unique identifier
/// This is a pure data model - SwiftTerm handles the actual PTY
class ShellSession: Identifiable, ObservableObject {
    let id: UUID
    let workingDirectory: String
    let shell: ShellType

    @Published var isRunning: Bool = false
    @Published var output: String = ""

    /// Parser for Claude CLI output
    private(set) lazy var claudeParser: ClaudeOutputParser = {
        ClaudeOutputParser(sessionId: id)
    }()

    /// Reference to the terminal view controller (set by TerminalView)
    weak var terminalViewController: RickTerminalViewController?

    /// Maximum output size to prevent memory issues (1MB)
    private let maxOutputSize = 1024 * 1024

    /// Lock for thread-safe output updates
    private let outputLock = NSLock()

    enum ShellType: String {
        case zsh = "/bin/zsh"
        case bash = "/bin/bash"

        static func detectDefault() -> ShellType {
            if let shell = ProcessInfo.processInfo.environment["SHELL"] {
                if shell.contains("zsh") {
                    return .zsh
                } else if shell.contains("bash") {
                    return .bash
                }
            }
            return .zsh // Default to zsh on macOS
        }
    }

    init(workingDirectory: String? = nil, shell: ShellType? = nil) {
        self.id = UUID()
        self.workingDirectory = workingDirectory ?? FileManager.default.currentDirectoryPath
        self.shell = shell ?? ShellType.detectDefault()
    }

    deinit {
        stop()
    }

    /// Start the shell session (delegates to SwiftTerm via terminal view controller)
    func start() throws {
        guard !isRunning else {
            let error = RTError.sessionAlreadyRunning
            ErrorManager.shared.handle(error, sessionId: id, presentToUser: false)
            return
        }

        // The actual shell process is started by RickTerminalViewController
        // This method is called to signal that the session should be active
        if let terminalVC = terminalViewController {
            terminalVC.startShell(workingDirectory: workingDirectory)
            DispatchQueue.main.async {
                self.isRunning = true
            }
        } else {
            // Terminal view controller not yet connected
            // The shell will start when the view is created
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    /// Stop the shell session
    func stop() {
        guard isRunning else { return }

        // The terminal view controller handles process termination
        // We just update our state
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    /// Restart the shell session
    func restart() throws {
        stop()
        try start()
    }

    /// Send input to the shell (delegates to SwiftTerm)
    func sendInput(_ input: String) {
        guard let terminalVC = terminalViewController else {
            print("[ShellSession] Warning: No terminal view controller connected for session \(id)")
            return
        }
        terminalVC.send(txt: input)
    }

    /// Process received output (called by terminal view controller)
    func processOutput(_ newOutput: String) {
        outputLock.lock()

        // Append output efficiently
        output += newOutput

        // Trim if output exceeds max size (keep last 75%)
        if output.count > maxOutputSize {
            let trimAmount = output.count - (maxOutputSize * 3 / 4)
            output = String(output.dropFirst(trimAmount))
        }

        outputLock.unlock()

        // Feed to Claude parser for tool event extraction
        claudeParser.process(newOutput)
    }

    /// Clear the terminal output
    func clearOutput() {
        outputLock.lock()
        output = ""
        outputLock.unlock()
    }

    // MARK: - Environment Helpers

    /// Get the inherited environment with Rick Terminal additions
    func getInheritedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        // Ensure critical variables are set
        if env["HOME"] == nil {
            env["HOME"] = NSHomeDirectory()
        }

        if env["USER"] == nil {
            env["USER"] = NSUserName()
        }

        if env["SHELL"] == nil {
            env["SHELL"] = shell.rawValue
        }

        if env["TERM"] == nil {
            env["TERM"] = "xterm-256color"
        }

        // Mark that we're in Rick Terminal for shell integration
        env["RICK_TERMINAL"] = "1"

        // Ensure PATH includes common binary locations
        // Apps launched from Finder/Xcode don't inherit shell PATH
        let additionalPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "~/.local/bin"
        ].map { NSString(string: $0).expandingTildeInPath }

        if var path = env["PATH"] {
            for additionalPath in additionalPaths {
                if !path.contains(additionalPath) {
                    path = "\(additionalPath):\(path)"
                }
            }
            env["PATH"] = path
        } else {
            env["PATH"] = additionalPaths.joined(separator: ":") + ":/usr/bin:/bin:/usr/sbin:/sbin"
        }

        return env
    }
}

enum ShellError: Error {
    case ptyCreationFailed
    case forkFailed
    case sessionNotRunning
}
