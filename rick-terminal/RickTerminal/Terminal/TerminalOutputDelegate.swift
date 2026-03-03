import Foundation

/// Protocol for receiving terminal output from SwiftTerm
/// This bridges the gap between SwiftTerm's PTY and our parsing infrastructure
protocol TerminalOutputDelegate: AnyObject {
    /// Called when new output is received from the terminal
    /// - Parameters:
    ///   - output: The output string received
    ///   - sessionId: The session this output belongs to
    func terminalDidReceiveOutput(_ output: String, sessionId: UUID)

    /// Called when the terminal process starts
    /// - Parameter sessionId: The session that started
    func terminalDidStart(sessionId: UUID)

    /// Called when the terminal process ends
    /// - Parameter sessionId: The session that ended
    func terminalDidEnd(sessionId: UUID)
}

/// Default implementations for optional delegate methods
extension TerminalOutputDelegate {
    func terminalDidStart(sessionId: UUID) {}
    func terminalDidEnd(sessionId: UUID) {}
}
