import Foundation
import Combine

/// Manages multiple shell sessions with unique identifiers
/// In the unified architecture, sessions are data models and SwiftTerm handles PTY
class ShellSessionManager: ObservableObject {
    @Published private(set) var sessions: [UUID: ShellSession] = [:]
    @Published var activeSessionId: UUID?
    @Published var claudeMode: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let settings = TerminalSettings.shared
    private let persistence = SessionPersistenceManager.shared

    /// Create a new shell session (data model only - PTY started by TerminalView)
    /// - Parameters:
    ///   - workingDirectory: Optional working directory (defaults to current directory)
    ///   - shell: Optional shell type (defaults to user's default shell)
    /// - Returns: The newly created session
    @discardableResult
    func createSession(
        workingDirectory: String? = nil,
        shell: ShellSession.ShellType? = nil
    ) -> ShellSession {
        let session = ShellSession(workingDirectory: workingDirectory, shell: shell)
        sessions[session.id] = session

        // Set as active if it's the first session
        if activeSessionId == nil {
            activeSessionId = session.id
        }

        // Monitor session state
        session.$isRunning
            .sink { [weak self, weak session] isRunning in
                guard let self = self, let session = session else { return }
                if !isRunning {
                    self.handleSessionTerminated(session)
                }
            }
            .store(in: &cancellables)

        return session
    }

    /// Start a session (in unified architecture, this just marks it ready)
    /// The actual shell process is started by TerminalView when it appears
    /// - Parameter sessionId: The session ID to start
    /// - Throws: ShellError if session not found
    func startSession(_ sessionId: UUID) throws {
        guard let session = sessions[sessionId] else {
            throw ShellError.sessionNotRunning
        }

        // In unified architecture, TerminalView handles shell startup
        // This is called for compatibility but the actual start happens in TerminalView
        if session.terminalViewController != nil {
            try session.start()
        }
        // If no terminal view yet, the session will start when TerminalView appears
    }

    /// Stop a session
    /// - Parameter sessionId: The session ID to stop
    func stopSession(_ sessionId: UUID) {
        sessions[sessionId]?.stop()
    }

    /// Restart a session
    /// - Parameter sessionId: The session ID to restart
    /// - Throws: ShellError if session not found or restart fails
    func restartSession(_ sessionId: UUID) throws {
        guard let session = sessions[sessionId] else {
            throw ShellError.sessionNotRunning
        }
        try session.restart()
    }

    /// Remove a session
    /// - Parameter sessionId: The session ID to remove
    /// - Parameter deletePersisted: Whether to delete the persisted session data (default: false)
    func removeSession(_ sessionId: UUID, deletePersisted: Bool = false) {
        if let session = sessions[sessionId] {
            session.stop()
            sessions.removeValue(forKey: sessionId)

            // If this was the active session, switch to another
            if activeSessionId == sessionId {
                activeSessionId = sessions.keys.first
            }

            // Optionally delete persisted data
            if deletePersisted {
                try? persistence.deleteSession(sessionId)
            }
        }
    }

    /// Get a session by ID
    /// - Parameter sessionId: The session ID
    /// - Returns: The session, or nil if not found
    func getSession(_ sessionId: UUID) -> ShellSession? {
        return sessions[sessionId]
    }

    /// Get the active session
    /// - Returns: The active session, or nil if none active
    func getActiveSession() -> ShellSession? {
        guard let id = activeSessionId else { return nil }
        return sessions[id]
    }

    /// Set the active session
    /// - Parameter sessionId: The session ID to make active
    func setActiveSession(_ sessionId: UUID) {
        guard sessions[sessionId] != nil else { return }
        activeSessionId = sessionId
    }

    /// Send input to a session (delegates to SwiftTerm via session)
    /// - Parameters:
    ///   - input: The input string to send
    ///   - sessionId: The session ID (defaults to active session)
    func sendInput(_ input: String, to sessionId: UUID? = nil) {
        let targetId = sessionId ?? activeSessionId
        guard let id = targetId else { return }
        sessions[id]?.sendInput(input)
    }

    /// Stop all sessions
    func stopAllSessions() {
        sessions.values.forEach { $0.stop() }
    }

    /// Remove all sessions
    /// - Parameter deletePersisted: Whether to delete all persisted session data (default: false)
    func removeAllSessions(deletePersisted: Bool = false) {
        stopAllSessions()
        sessions.removeAll()
        activeSessionId = nil

        if deletePersisted {
            try? persistence.deleteAllSessions()
        }
    }

    /// Get all session IDs
    var sessionIds: [UUID] {
        return Array(sessions.keys)
    }

    /// Get the number of active sessions
    var sessionCount: Int {
        return sessions.count
    }

    // MARK: - Claude Integration

    /// Launch Claude CLI in the active session
    /// - Returns: true if launched successfully, false otherwise
    @discardableResult
    func launchClaude() -> Bool {
        // Check if Claude CLI path is configured
        guard let claudePath = settings.getClaudeCliPath() else {
            ErrorManager.shared.handle(.claudeNotConfigured, sessionId: activeSessionId)
            return false
        }

        // Check if there's an active session
        guard let sessionId = activeSessionId else {
            ErrorManager.shared.handle(.sessionNotFound, presentToUser: true)
            return false
        }

        // Check if Claude is already running
        guard !claudeMode else {
            ErrorManager.shared.handle(.claudeAlreadyRunning, presentToUser: false)
            return false
        }

        // Send the claude command to the shell
        print("[ShellSessionManager] Launching Claude from: \(claudePath)")
        sendInput("claude\n", to: sessionId)
        claudeMode = true
        return true
    }

    /// Exit Claude CLI mode (send exit command)
    func exitClaude() {
        guard claudeMode else {
            ErrorManager.shared.handle(.claudeNotRunning, presentToUser: false)
            return
        }

        if let sessionId = activeSessionId {
            sendInput("exit\n", to: sessionId)
        } else {
            ErrorManager.shared.handle(.sessionNotFound, presentToUser: false)
        }
        claudeMode = false
    }

    /// Toggle Claude mode on/off
    /// - Returns: new claude mode state
    @discardableResult
    func toggleClaudeMode() -> Bool {
        if claudeMode {
            exitClaude()
            return false
        } else {
            return launchClaude()
        }
    }

    /// Check if auto-launch should happen and launch if appropriate
    func handleAutoLaunchIfNeeded() {
        guard settings.claudeAutoLaunch else { return }
        guard settings.getClaudeCliPath() != nil else { return }

        // Wait a short delay for shell to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.launchClaude()
        }
    }

    // MARK: - Session Persistence

    /// Save current sessions to disk
    func saveAllSessions() {
        let states = sessions.values.map { session in
            PersistedSessionState(from: session)
        }

        do {
            try persistence.saveSessions(states)
            persistence.saveCurrentSession(activeSessionId)
        } catch {
            ErrorManager.shared.handle(.sessionSaveFailed, additionalInfo: ["error": error.localizedDescription])
        }
    }

    /// Save a specific session to disk
    func saveSession(_ sessionId: UUID) {
        guard let session = sessions[sessionId] else { return }

        do {
            let state = PersistedSessionState(from: session)
            try persistence.saveSession(state)
        } catch {
            ErrorManager.shared.handle(.sessionSaveFailed, additionalInfo: [
                "sessionId": sessionId.uuidString,
                "error": error.localizedDescription
            ])
        }
    }

    /// Restore a previously saved session
    /// - Parameter sessionId: The session ID to restore
    /// - Returns: true if restored successfully
    @discardableResult
    func restoreSession(_ sessionId: UUID) -> Bool {
        do {
            let state = try persistence.loadSession(sessionId)
            let shellType = ShellSession.ShellType(rawValue: state.shellType) ?? .zsh

            // Create session with restored settings (PTY will start when TerminalView appears)
            _ = createSession(workingDirectory: state.workingDirectory, shell: shellType)

            return true
        } catch {
            ErrorManager.shared.handle(.sessionRestoreFailed, additionalInfo: [
                "sessionId": sessionId.uuidString,
                "error": error.localizedDescription
            ])
            return false
        }
    }

    /// Restore the last active session
    /// - Returns: true if a session was restored
    @discardableResult
    func restoreLastSession() -> Bool {
        guard let sessionId = persistence.loadCurrentSessionId() else {
            return false
        }

        let success = restoreSession(sessionId)
        if success {
            activeSessionId = sessionId
        }
        return success
    }

    /// Get all persisted session states
    func getPersistedSessions() -> [PersistedSessionState] {
        return persistence.loadAllSessions()
    }

    /// Delete a persisted session
    func deletePersistedSession(_ sessionId: UUID) {
        try? persistence.deleteSession(sessionId)
    }

    /// Clean up old persisted sessions
    func cleanupOldSessions(olderThanDays days: Int = 30) {
        try? persistence.cleanupOldSessions(olderThanDays: days)
    }

    // MARK: - Private Helpers

    private func handleSessionTerminated(_ session: ShellSession) {
        // Optionally auto-remove terminated sessions
        // For now, we just keep them around so user can see the output
    }
}

// MARK: - Convenience Extensions

extension ShellSessionManager {
    /// Create and start a new session in one call
    /// In unified architecture, the "start" happens when TerminalView appears
    /// - Parameters:
    ///   - workingDirectory: Optional working directory
    ///   - shell: Optional shell type
    /// - Returns: The newly created session
    @discardableResult
    func createAndStartSession(
        workingDirectory: String? = nil,
        shell: ShellSession.ShellType? = nil
    ) throws -> ShellSession {
        let session = createSession(workingDirectory: workingDirectory, shell: shell)
        // In unified architecture, TerminalView handles the actual shell startup
        // No need to call session.start() here - it happens when the view appears
        return session
    }
}
