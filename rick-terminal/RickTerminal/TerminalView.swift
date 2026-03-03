import SwiftUI
import AppKit
import SwiftTerm

/// NSViewRepresentable wrapper for RickTerminalViewController
/// Bridges AppKit (NSView) to SwiftUI for terminal emulation with enhanced copy/paste support
/// Now with proper session binding for unified shell architecture
struct TerminalView: NSViewRepresentable {
    typealias NSViewType = RickTerminalViewController

    /// The session this terminal is bound to (optional for standalone use)
    @ObservedObject var session: ShellSession

    // MARK: - Initialization

    init(session: ShellSession) {
        self.session = session
    }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> RickTerminalViewController {
        let terminalView = RickTerminalViewController(frame: .zero)

        // Configure terminal appearance
        configureTerminalAppearance(terminalView)

        // Connect session to terminal view controller
        terminalView.session = session
        terminalView.sessionId = session.id
        session.terminalViewController = terminalView

        // Start the shell process with session's working directory
        terminalView.startShell(workingDirectory: session.workingDirectory)

        // Mark session as running
        DispatchQueue.main.async {
            session.isRunning = true
        }

        // Store reference in coordinator for cleanup
        context.coordinator.terminalView = terminalView
        context.coordinator.session = session

        return terminalView
    }

    func updateNSView(_ nsView: RickTerminalViewController, context: Context) {
        // Ensure terminal has keyboard focus when view updates
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }

        // Re-establish session connection if needed
        if nsView.session !== session {
            nsView.session = session
            nsView.sessionId = session.id
            session.terminalViewController = nsView
        }
    }

    static func dismantleNSView(_ nsView: RickTerminalViewController, coordinator: Coordinator) {
        // Clean up terminal process on view dismount to prevent memory leaks
        coordinator.cleanup()
    }

    // MARK: - Configuration

    private func configureTerminalAppearance(_ terminal: RickTerminalViewController) {
        // Apply Rick Terminal theme colors
        terminal.nativeForegroundColor = NSColor(Color.rtAccentGreen)
        terminal.nativeBackgroundColor = NSColor(Color.rtBackgroundDark)

        // Set terminal font
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.font = font

        // Configure cursor
        terminal.caretColor = NSColor(Color.rtAccentPurple)

        // Selection is enabled by default in RickTerminalViewController
        // allowMouseReporting is disabled to allow text selection
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var terminalView: RickTerminalViewController?
        weak var session: ShellSession?

        func cleanup() {
            // Disconnect session from terminal view
            if let session = session {
                session.terminalViewController = nil
                session.isRunning = false
            }

            // Clean up reference to prevent memory leaks
            // RickTerminalViewController handles process termination automatically
            terminalView = nil
            session = nil
        }
    }
}

// MARK: - Standalone Terminal View (for backwards compatibility)

/// A standalone terminal view without session binding
/// Use this when you just need a terminal without session management
struct StandaloneTerminalView: NSViewRepresentable {
    typealias NSViewType = RickTerminalViewController

    func makeNSView(context: Context) -> RickTerminalViewController {
        let terminalView = RickTerminalViewController(frame: .zero)

        // Configure terminal appearance
        configureTerminalAppearance(terminalView)

        // Start the shell process
        terminalView.startShell()

        // Store reference in coordinator for cleanup
        context.coordinator.terminalView = terminalView

        return terminalView
    }

    func updateNSView(_ nsView: RickTerminalViewController, context: Context) {
        // Ensure terminal has keyboard focus when view updates
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    static func dismantleNSView(_ nsView: RickTerminalViewController, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    private func configureTerminalAppearance(_ terminal: RickTerminalViewController) {
        terminal.nativeForegroundColor = NSColor(Color.rtAccentGreen)
        terminal.nativeBackgroundColor = NSColor(Color.rtBackgroundDark)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.caretColor = NSColor(Color.rtAccentPurple)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var terminalView: RickTerminalViewController?

        func cleanup() {
            terminalView = nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        StandaloneTerminalView()
            .frame(width: 800, height: 600)
    }
}
#endif
