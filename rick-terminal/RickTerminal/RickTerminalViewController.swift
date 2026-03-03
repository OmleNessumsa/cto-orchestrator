import AppKit
import SwiftTerm

/// Protocol for receiving terminal output
protocol TerminalOutputReceiver: AnyObject {
    func terminalDidReceiveOutput(_ output: String, sessionId: UUID)
    func terminalDidStart(sessionId: UUID)
    func terminalDidEnd(sessionId: UUID)
}

/// Default implementations
extension TerminalOutputReceiver {
    func terminalDidStart(sessionId: UUID) {}
    func terminalDidEnd(sessionId: UUID) {}
}

/// Custom terminal view using SwiftTerm's LocalProcessTerminalView
/// Configured with Rick Terminal theme colors and enhanced interaction
/// Now includes output capture for parsing and session integration
class RickTerminalViewController: LocalProcessTerminalView {

    // MARK: - Session Integration

    /// The session this terminal is associated with
    weak var session: ShellSession?

    /// Session ID for output forwarding
    var sessionId: UUID?

    /// Output receiver for forwarding terminal output
    weak var outputReceiver: TerminalOutputReceiver?

    // MARK: - Resize Handling

    /// Debounce timer for resize events to avoid excessive PTY updates
    private var resizeDebounceTimer: Timer?

    /// Debounce interval in seconds (250ms provides smooth resizing without flickering)
    private let resizeDebounceInterval: TimeInterval = 0.25

    /// Track last known size to avoid redundant resize operations
    private var lastKnownSize: CGSize = .zero

    // MARK: - Delegate Wrapper

    /// Wrapper to receive delegate callbacks
    private var delegateWrapper: ProcessDelegateWrapper?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTerminal()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTerminal()
    }

    private func setupTerminal() {
        // Disable mouse reporting to allow text selection
        allowMouseReporting = false

        // Set up delegate wrapper for process events
        delegateWrapper = ProcessDelegateWrapper(controller: self)
        processDelegate = delegateWrapper

        // The built-in copy/paste from SwiftTerm's TerminalView works with:
        // - Cmd+C for copy (when there's a selection)
        // - Cmd+V for paste
        // - Cmd+A for select all
        // - Right-click context menu
    }

    // MARK: - View Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Initialize size tracking when view appears
        if window != nil {
            lastKnownSize = bounds.size
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        // Only process resize if size actually changed
        guard newSize != lastKnownSize else { return }

        // Debounce resize events to avoid excessive PTY updates
        handleResizeDebounced(newSize: newSize)
    }

    // MARK: - Resize Event Handling

    /// Debounce resize events to avoid performance issues during window drag
    private func handleResizeDebounced(newSize: NSSize) {
        // Cancel any pending resize operation
        resizeDebounceTimer?.invalidate()

        // Schedule new resize operation after debounce interval
        resizeDebounceTimer = Timer.scheduledTimer(withTimeInterval: resizeDebounceInterval, repeats: false) { [weak self] _ in
            self?.performResize(newSize: newSize)
        }
    }

    /// Execute the actual resize operation
    private func performResize(newSize: NSSize) {
        guard newSize != lastKnownSize else { return }

        // Update tracked size
        lastKnownSize = newSize

        // SwiftTerm's TerminalView automatically calculates the correct
        // number of columns and rows based on the view size and font metrics.
        // We just need to trigger a layout update.
        // The parent class handles communicating the new dimensions to the PTY
        // via the underlying terminal emulator.
        needsLayout = true
        layoutSubtreeIfNeeded()

        // Force a display update to ensure text reflows properly
        needsDisplay = true
    }

    deinit {
        // Clean up timers to prevent memory leaks
        resizeDebounceTimer?.invalidate()
    }

    // MARK: - Data Capture

    /// Override dataReceived to capture terminal output
    /// This method is called by SwiftTerm when data is received from the PTY
    override func dataReceived(slice: ArraySlice<UInt8>) {
        // Call super to let SwiftTerm handle display
        super.dataReceived(slice: slice)

        // Convert to string for our parser
        guard let string = String(bytes: slice, encoding: .utf8) else { return }

        // Forward to session for parsing
        if let session = session {
            session.processOutput(string)
        } else if let sessionId = sessionId {
            outputReceiver?.terminalDidReceiveOutput(string, sessionId: sessionId)
        }
    }

    // MARK: - Shell Process Management

    /// Start the shell process with the user's default shell
    func startShell() {
        // Prevent socket inheritance by marking all FDs as close-on-exec
        FileDescriptorUtils.markAllFileDescriptorsCloseOnExec()

        // Get user's default shell
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        // Get home directory
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Build environment with proper PATH
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin"
        ]

        if var path = env["PATH"] {
            for additionalPath in additionalPaths {
                if !path.contains(additionalPath) {
                    path = "\(additionalPath):\(path)"
                }
            }
            env["PATH"] = path
        }

        // Ensure TERM is set for proper terminal emulation
        env["TERM"] = "xterm-256color"

        // Mark that we're in Rick Terminal for shell integration
        env["RICK_TERMINAL"] = "1"

        // Convert environment to array format
        let envArray = env.map { "\($0.key)=\($0.value)" }

        // Start the process
        startProcess(executable: shell, args: ["-l"], environment: envArray, execName: nil)

        // Change to home directory
        send(txt: "cd \"\(home)\" && clear\n")

        // Notify that terminal started
        if let sessionId = sessionId {
            outputReceiver?.terminalDidStart(sessionId: sessionId)
        }
    }

    /// Start the shell process with a specific working directory
    /// - Parameter workingDirectory: The directory to start in
    func startShell(workingDirectory: String) {
        // Prevent socket inheritance by marking all FDs as close-on-exec
        FileDescriptorUtils.markAllFileDescriptorsCloseOnExec()

        // Get user's default shell
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        // Build environment with proper PATH
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin"
        ]

        if var path = env["PATH"] {
            for additionalPath in additionalPaths {
                if !path.contains(additionalPath) {
                    path = "\(additionalPath):\(path)"
                }
            }
            env["PATH"] = path
        }

        // Ensure TERM is set for proper terminal emulation
        env["TERM"] = "xterm-256color"

        // Mark that we're in Rick Terminal for shell integration
        env["RICK_TERMINAL"] = "1"

        // Set working directory in environment
        env["PWD"] = workingDirectory

        // Convert environment to array format
        let envArray = env.map { "\($0.key)=\($0.value)" }

        // Start the process
        startProcess(executable: shell, args: ["-l"], environment: envArray, execName: nil)

        // Change to specified directory
        send(txt: "cd \"\(workingDirectory)\" && clear\n")

        // Notify that terminal started
        if let sessionId = sessionId {
            outputReceiver?.terminalDidStart(sessionId: sessionId)
        }
    }

    // MARK: - Process Delegate Callbacks

    func handleProcessTerminated(exitCode: Int32?) {
        // Shell process ended
        if let sessionId = sessionId {
            outputReceiver?.terminalDidEnd(sessionId: sessionId)
        }

        // Update session state
        DispatchQueue.main.async { [weak self] in
            self?.session?.isRunning = false
        }
    }
}

// MARK: - Process Delegate Wrapper

/// Wrapper class to receive LocalProcessTerminalViewDelegate callbacks
private class ProcessDelegateWrapper: LocalProcessTerminalViewDelegate {
    weak var controller: RickTerminalViewController?

    init(controller: RickTerminalViewController) {
        self.controller = controller
    }

    func sizeChanged(source: SwiftTerm.LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // Terminal size changed, handled by parent class
    }

    func setTerminalTitle(source: SwiftTerm.LocalProcessTerminalView, title: String) {
        // Could update window title here if desired
    }

    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        // Working directory changed
    }

    func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        controller?.handleProcessTerminated(exitCode: exitCode)
    }
}
