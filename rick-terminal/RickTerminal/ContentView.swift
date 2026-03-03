import SwiftUI

struct ContentView: View {
    @ObservedObject var sessionManager: ShellSessionManager

    init(sessionManager: ShellSessionManager? = nil) {
        self.sessionManager = sessionManager ?? ShellSessionManager()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Session tabs
            if !sessionManager.sessions.isEmpty {
                sessionTabsView
            }

            // Terminal view (SwiftTerm-based)
            terminalContentView
        }
        .background(Color.rtBackgroundDark)
        .onAppear {
            createInitialSessionIfNeeded()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            Text("Rick Terminal")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.rtAccentGreen)

            Spacer()

            // Claude mode indicator
            if sessionManager.claudeMode {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.rtAccentPurple)
                        .frame(width: 8, height: 8)
                    Text("Claude Active")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.rtAccentPurple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.rtAccentPurple.opacity(0.1))
                .cornerRadius(4)
            }

            Text("Sessions: \(sessionManager.sessionCount)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.rtTextSecondary)

            Button(action: createNewSession) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.rtAccentGreen)
            }
            .buttonStyle(.plain)
            .help("New Session (⌘T)")
        }
        .padding(8)
        .background(Color.rtBackgroundLight)
    }

    private var sessionTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sessionManager.sessionIds, id: \.self) { sessionId in
                    sessionTab(for: sessionId)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color.rtBackgroundLight.opacity(0.5))
    }

    private func sessionTab(for sessionId: UUID) -> some View {
        let isActive = sessionManager.activeSessionId == sessionId
        let session = sessionManager.getSession(sessionId)
        let isRunning = session?.isRunning ?? false

        return HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? Color.rtAccentGreen : Color.rtAccentOrange)
                .frame(width: 6, height: 6)

            Text(sessionId.uuidString.prefix(8))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isActive ? .rtTextPrimary : .rtTextSecondary)

            Button(action: { closeSession(sessionId) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.rtTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color.rtAccentGreen.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? Color.rtAccentGreen.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            sessionManager.setActiveSession(sessionId)
        }
    }

    private var terminalContentView: some View {
        Group {
            if let session = sessionManager.getActiveSession() {
                // Use TerminalView with session binding
                // This displays SwiftTerm directly - no Text() wrapper needed
                TerminalView(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No active session placeholder
                VStack(spacing: 16) {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundColor(.rtTextSecondary)

                    Text("No active session")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)

                    Button("Create New Session") {
                        createNewSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.rtAccentGreen)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.rtBackgroundDark)
            }
        }
    }

    // MARK: - Actions

    private func createInitialSessionIfNeeded() {
        // Only create a session if there are no active sessions
        // This allows session restoration to happen first
        if sessionManager.sessions.isEmpty {
            // Create session without starting PTY (TerminalView handles that)
            let _ = sessionManager.createSession()
            // Trigger auto-launch after session is created
            sessionManager.handleAutoLaunchIfNeeded()
        }
    }

    private func createNewSession() {
        // Create session without starting PTY (TerminalView handles that)
        let _ = sessionManager.createSession()
    }

    private func closeSession(_ sessionId: UUID) {
        sessionManager.removeSession(sessionId)
    }

    /// Toggle Claude CLI mode (exposed for keyboard shortcut)
    func toggleClaude() {
        sessionManager.toggleClaudeMode()
    }

    /// Get the session manager (exposed for parent views)
    func getSessionManager() -> ShellSessionManager {
        return sessionManager
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 800, height: 600)
    }
}
