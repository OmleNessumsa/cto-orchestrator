import SwiftUI

/// Main window with three-column split view layout
/// Left: File browser | Center: Terminal/Editor | Right: Kanban & Agent columns
struct MainWindowView: View {
    @StateObject private var layoutState = LayoutState()
    @StateObject private var sessionManager = ShellSessionManager()
    @StateObject private var agentColumnsManager = AgentColumnsManager()
    @StateObject private var kanbanManager = KanbanManager()
    @StateObject private var editorManager = EditorManager()
    @StateObject private var claudeProgressManager = ClaudeProgressManager()
    @StateObject private var ctoEventBridge = CTOEventBridge()
    @State private var showKeyboardShortcuts = false
    @State private var showSessionRestoration = false
    @State private var showSessionHistory = false

    // Window restoration support
    @SceneStorage("windowId") private var windowId: String = UUID().uuidString
    @SceneStorage("isLeftSidebarCollapsed") private var savedLeftSidebarCollapsed: Bool = false
    @SceneStorage("isRightPanelCollapsed") private var savedRightPanelCollapsed: Bool = false
    @SceneStorage("leftSidebarWidth") private var savedLeftSidebarWidth: Double = 200
    @SceneStorage("rightPanelWidth") private var savedRightPanelWidth: Double = 300

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Sidebar - File Browser
                if !layoutState.isLeftSidebarCollapsed {
                    FileBrowserView()
                        .frame(width: layoutState.leftSidebarWidth)
                        .background(Color.rtBackgroundLight)

                    DividerHandle(
                        width: layoutState.leftSidebarWidth,
                        minWidth: LayoutState.minLeftSidebarWidth,
                        maxWidth: LayoutState.maxLeftSidebarWidth
                    ) { newWidth in
                        layoutState.leftSidebarWidth = newWidth
                    }
                }

                // Center Panel - Terminal/Editor
                CenterPanelView(
                    sessionManager: sessionManager,
                    editorManager: editorManager,
                    claudeProgressManager: claudeProgressManager
                )
                .frame(maxWidth: .infinity)
                .background(Color.rtBackgroundDark)

                // Right Panel - Kanban & Agent Columns
                if !layoutState.isRightPanelCollapsed {
                    DividerHandle(
                        width: layoutState.rightPanelWidth,
                        minWidth: LayoutState.minRightPanelWidth,
                        maxWidth: LayoutState.maxRightPanelWidth,
                        isRightHandle: true
                    ) { newWidth in
                        layoutState.rightPanelWidth = newWidth
                    }

                    RightPanelView(
                        agentColumnsManager: agentColumnsManager,
                        kanbanManager: kanbanManager
                    )
                    .frame(width: layoutState.rightPanelWidth)
                    .background(Color.rtBackgroundLight)
                }

                // Toolbar for collapsing panels
                LayoutToolbar(layoutState: layoutState)
            }
        }
        .background(Color.rtBackgroundDark)
        .navigationTitle(windowTitle)
        .navigationSubtitle(windowSubtitle)
        .environmentObject(layoutState)
        .environmentObject(sessionManager)
        .environmentObject(agentColumnsManager)
        .environmentObject(kanbanManager)
        .environmentObject(editorManager)
        // Claude shortcuts
        .onReceive(NotificationCenter.default.publisher(for: .toggleClaudeMode)) { _ in
            sessionManager.toggleClaudeMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchClaude)) { _ in
            sessionManager.launchClaude()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exitClaude)) { _ in
            sessionManager.exitClaude()
        }
        // File shortcuts
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            editorManager.saveActiveFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveAll)) { _ in
            editorManager.saveAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeFile)) { _ in
            if let activeFile = editorManager.activeFile {
                editorManager.closeFile(activeFile)
            }
        }
        // View shortcuts
        .onReceive(NotificationCenter.default.publisher(for: .toggleFileBrowser)) { _ in
            layoutState.toggleLeftSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleKanban)) { _ in
            layoutState.toggleRightPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            showKeyboardShortcuts = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSessionHistory)) { _ in
            showSessionHistory = true
        }
        // Terminal shortcuts
        .onReceive(NotificationCenter.default.publisher(for: .clearTerminal)) { _ in
            // Send clear command to terminal
            sessionManager.sendInput("clear\n")
        }
        .onReceive(NotificationCenter.default.publisher(for: .interruptProcess)) { _ in
            // Send Ctrl+C (interrupt signal) to terminal
            sessionManager.sendInput("\u{03}")
        }
        .sheet(isPresented: $showKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: $showSessionRestoration) {
            SessionRestorationView(
                sessions: sessionManager.getPersistedSessions(),
                onRestore: { sessionId in
                    sessionManager.restoreSession(sessionId)
                    showSessionRestoration = false
                },
                onDismiss: {
                    showSessionRestoration = false
                }
            )
        }
        .sheet(isPresented: $showSessionHistory) {
            SessionHistoryView(sessionManager: sessionManager)
        }
        .errorAlert() // Enable error handling alerts
        .onAppear {
            connectParsers()
            restoreWindowState()
            checkForSessionRestoration()
            startCTOIntegration()
        }
        .onDisappear {
            saveSessionsOnClose()
            stopCTOIntegration()
        }
        .onChange(of: sessionManager.activeSessionId) { _ in
            connectParsers()
        }
        .onChange(of: layoutState.isLeftSidebarCollapsed) { newValue in
            savedLeftSidebarCollapsed = newValue
        }
        .onChange(of: layoutState.isRightPanelCollapsed) { newValue in
            savedRightPanelCollapsed = newValue
        }
        .onChange(of: layoutState.leftSidebarWidth) { newValue in
            savedLeftSidebarWidth = Double(newValue)
        }
        .onChange(of: layoutState.rightPanelWidth) { newValue in
            savedRightPanelWidth = Double(newValue)
        }
    }

    // MARK: - Parser Connection

    /// Connect the active session's parser to managers
    private func connectParsers() {
        guard let session = sessionManager.getActiveSession() else {
            agentColumnsManager.unsubscribe()
            kanbanManager.unsubscribe()
            claudeProgressManager.unsubscribe()
            return
        }

        agentColumnsManager.subscribe(to: session.claudeParser)
        kanbanManager.subscribe(to: session.claudeParser)
        claudeProgressManager.subscribe(to: session.claudeParser)
    }

    // MARK: - Window State Restoration

    /// Restore window state from scene storage
    private func restoreWindowState() {
        layoutState.isLeftSidebarCollapsed = savedLeftSidebarCollapsed
        layoutState.isRightPanelCollapsed = savedRightPanelCollapsed
        layoutState.leftSidebarWidth = CGFloat(savedLeftSidebarWidth)
        layoutState.rightPanelWidth = CGFloat(savedRightPanelWidth)
    }

    // MARK: - Session Persistence

    /// Check if there are saved sessions and prompt for restoration
    private func checkForSessionRestoration() {
        // Temporarily disabled to debug freezing issue
        // let savedSessions = sessionManager.getPersistedSessions()
        // if !savedSessions.isEmpty {
        //     showSessionRestoration = true
        // }
    }

    /// Save all sessions when the window closes
    private func saveSessionsOnClose() {
        sessionManager.saveAllSessions()
    }

    // MARK: - CTO Integration

    /// Start CTO-Orchestrator event bridge
    private func startCTOIntegration() {
        ctoEventBridge.connect(kanban: kanbanManager, agents: agentColumnsManager)
        ctoEventBridge.start()
    }

    /// Stop CTO-Orchestrator event bridge
    private func stopCTOIntegration() {
        ctoEventBridge.stop()
    }

    // MARK: - Window Title

    /// Compute window title based on current state
    private var windowTitle: String {
        if sessionManager.claudeMode {
            return "Rick Terminal - Claude Mode"
        }

        if let activeSession = sessionManager.getActiveSession() {
            let sessionNumber = sessionManager.sessionIds.firstIndex(of: activeSession.id).map { $0 + 1 } ?? 1
            return "Rick Terminal - Session \(sessionNumber)"
        }

        return "Rick Terminal"
    }

    /// Compute window subtitle
    private var windowSubtitle: String {
        return "\(sessionManager.sessionCount) session\(sessionManager.sessionCount == 1 ? "" : "s")"
    }
}

// MARK: - Layout State

class LayoutState: ObservableObject {
    // Panel widths (using Double for AppStorage compatibility)
    @AppStorage("leftSidebarWidth") private var _leftSidebarWidth: Double = 200
    @AppStorage("rightPanelWidth") private var _rightPanelWidth: Double = 300

    var leftSidebarWidth: CGFloat {
        get { CGFloat(_leftSidebarWidth) }
        set { _leftSidebarWidth = Double(newValue) }
    }

    var rightPanelWidth: CGFloat {
        get { CGFloat(_rightPanelWidth) }
        set { _rightPanelWidth = Double(newValue) }
    }

    // Collapsed states
    @AppStorage("isLeftSidebarCollapsed") var isLeftSidebarCollapsed: Bool = false
    @AppStorage("isRightPanelCollapsed") var isRightPanelCollapsed: Bool = false

    // Width constraints
    static let minLeftSidebarWidth: CGFloat = 150
    static let maxLeftSidebarWidth: CGFloat = 400
    static let minRightPanelWidth: CGFloat = 250
    static let maxRightPanelWidth: CGFloat = 600

    func toggleLeftSidebar() {
        isLeftSidebarCollapsed.toggle()
    }

    func toggleRightPanel() {
        isRightPanelCollapsed.toggle()
    }
}

// MARK: - Divider Handle

struct DividerHandle: View {
    let width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    var isRightHandle: Bool = false
    let onDrag: (CGFloat) -> Void

    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.rtAccentGreen.opacity(0.3) : Color.rtBorderSubtle)
            .frame(width: 1)
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 10)
            )
            .contentShape(Rectangle().size(width: 10, height: .infinity))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartWidth = width
                        }

                        let delta = isRightHandle ? -value.translation.width : value.translation.width
                        let newWidth = max(minWidth, min(maxWidth, dragStartWidth + delta))
                        onDrag(newWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .cursor(.resizeLeftRight)
    }
}

// MARK: - Layout Toolbar

struct LayoutToolbar: View {
    @ObservedObject var layoutState: LayoutState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                // Toggle left sidebar
                Button(action: { layoutState.toggleLeftSidebar() }) {
                    Image(systemName: layoutState.isLeftSidebarCollapsed ? "sidebar.left" : "sidebar.left.fill")
                        .foregroundColor(.rtAccentGreen)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(layoutState.isLeftSidebarCollapsed ? "Show File Browser" : "Hide File Browser")

                Divider()
                    .frame(width: 20)
                    .background(Color.rtBorderSubtle)

                // Toggle right panel
                Button(action: { layoutState.toggleRightPanel() }) {
                    Image(systemName: layoutState.isRightPanelCollapsed ? "sidebar.right" : "sidebar.right.fill")
                        .foregroundColor(.rtAccentGreen)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(layoutState.isRightPanelCollapsed ? "Show Kanban Board" : "Hide Kanban Board")
            }
            .padding(8)
            .background(Color.rtBackgroundLight.opacity(0.8))
            .cornerRadius(8)
            .padding(.bottom, 16)
            .padding(.trailing, 8)
        }
    }
}

// MARK: - Panel Views

struct CenterPanelView: View {
    @ObservedObject var sessionManager: ShellSessionManager
    @ObservedObject var editorManager: EditorManager
    @ObservedObject var claudeProgressManager: ClaudeProgressManager
    @State private var showEditor: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Toggle bar
                HStack(spacing: 0) {
                    // Terminal tab
                    Button(action: { showEditor = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 11))
                            Text("Terminal")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showEditor ? Color.clear : Color.rtBackgroundDark)
                        .foregroundColor(showEditor ? .rtTextSecondary : .rtTextPrimary)
                    }
                    .buttonStyle(.plain)

                    // Editor tab
                    Button(action: { showEditor = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                            Text("Editor")
                                .font(.system(size: 12, design: .monospaced))

                            // Unsaved changes indicator
                            if editorManager.hasUnsavedChanges {
                                Circle()
                                    .fill(Color.rtAccentGreen)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showEditor ? Color.rtBackgroundDark : Color.clear)
                        .foregroundColor(showEditor ? .rtTextPrimary : .rtTextSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .background(Color.rtBackgroundLight)

                Divider()
                    .background(Color.rtBorderSubtle)

                // Content
                if showEditor {
                    EditorPanelView(editorManager: editorManager)
                } else {
                    ContentView(sessionManager: sessionManager)
                }
            }

            // Claude Progress Overlay (only when in terminal mode and Claude is active)
            if !showEditor && sessionManager.claudeMode {
                VStack {
                    Spacer()
                        .frame(height: 50) // Below the tab bar

                    ClaudeProgressOverlay(progressManager: claudeProgressManager)

                    Spacer()
                }
            }
        }
        .onChange(of: editorManager.activeFileId) { newValue in
            // Auto-switch to editor when a file is opened
            if newValue != nil {
                showEditor = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTerminal)) { _ in
            showEditor = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToEditor)) { _ in
            showEditor = true
        }
    }
}

struct RightPanelView: View {
    @ObservedObject var agentColumnsManager: AgentColumnsManager
    @ObservedObject var kanbanManager: KanbanManager

    var body: some View {
        VStack(spacing: 0) {
            // Kanban Board Section - Real Implementation
            KanbanBoardView(
                board: kanbanManager.board,
                bridge: kanbanManager.bridge
            )
            .frame(maxHeight: .infinity)

            Divider()
                .background(Color.rtBorderSubtle)

            // Agent Columns Section - Real Implementation
            AgentColumnsContainer(manager: agentColumnsManager, containerHeight: 300)
        }
    }
}

// MARK: - Custom Cursor Modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Preview

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .frame(width: 1200, height: 800)
    }
}
