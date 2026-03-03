import SwiftUI

/// Main window with three-column layout
struct MainWindowView: View {
    @StateObject private var sessionManager = ShellSessionManager()
    @StateObject private var agentColumnsManager = AgentColumnsManager()
    @StateObject private var kanbanManager = KanbanManager()
    @StateObject private var editorManager = EditorManager()
    @StateObject private var claudeProgressManager = ClaudeProgressManager()
    @StateObject private var ctoEventBridge = CTOEventBridge()

    @State private var showKeyboardShortcuts = false
    @State private var showSessionRestoration = false
    @State private var showSessionHistory = false

    // Layout state - persisted
    @AppStorage("layout.leftCollapsed") private var isLeftCollapsed = false
    @AppStorage("layout.rightCollapsed") private var isRightCollapsed = false
    @AppStorage("layout.agentCollapsed") private var isAgentCollapsed = false
    @AppStorage("layout.leftWidth") private var savedLeftWidth: Double = 220
    @AppStorage("layout.rightWidth") private var savedRightWidth: Double = 320
    @AppStorage("layout.agentHeight") private var savedAgentHeight: Double = 250

    // Runtime state for smooth dragging
    @State private var leftWidth: CGFloat = 220
    @State private var rightWidth: CGFloat = 320
    @State private var agentHeight: CGFloat = 250
    @State private var didRestoreLayout = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: File Browser
            if !isLeftCollapsed {
                FileBrowserView()
                    .frame(width: leftWidth)
                    .background(Color.rtBackgroundLight)

                DragHandle(
                    value: $leftWidth,
                    min: 150, max: 400,
                    axis: .horizontal,
                    onEnd: { savedLeftWidth = Double(leftWidth) }
                )
            }

            // Center: Terminal/Editor
            CenterPanelView(
                sessionManager: sessionManager,
                editorManager: editorManager,
                claudeProgressManager: claudeProgressManager
            )
            .frame(maxWidth: .infinity)
            .background(Color.rtBackgroundDark)

            // Right: Kanban & Agents
            if !isRightCollapsed {
                DragHandle(
                    value: $rightWidth,
                    min: 280, max: 2000,
                    axis: .horizontal,
                    invert: true,
                    onEnd: { savedRightWidth = Double(rightWidth) }
                )

                RightPanelView(
                    kanbanManager: kanbanManager,
                    agentColumnsManager: agentColumnsManager,
                    isAgentCollapsed: $isAgentCollapsed,
                    agentHeight: $agentHeight,
                    onAgentHeightChange: { savedAgentHeight = Double(agentHeight) }
                )
                .frame(width: rightWidth)
                .background(Color.rtBackgroundLight)
            }
        }
        .onAppear {
            // Restore layout (only once)
            if !didRestoreLayout {
                leftWidth = CGFloat(savedLeftWidth)
                rightWidth = CGFloat(savedRightWidth)
                agentHeight = CGFloat(savedAgentHeight)
                didRestoreLayout = true

                // Initialize CTO integration (only on first appear)
                agentColumnsManager.clearAll()
                connectParsers()
                ctoEventBridge.connect(kanban: kanbanManager, agents: agentColumnsManager)
                ctoEventBridge.start()
            }
        }
        .toolbar { makeToolbar() }
        .environmentObject(sessionManager)
        .environmentObject(agentColumnsManager)
        .environmentObject(kanbanManager)
        .environmentObject(editorManager)
        .environmentObject(ctoEventBridge)
        .modifier(NotificationModifier(
            sessionManager: sessionManager,
            editorManager: editorManager,
            isLeftCollapsed: $isLeftCollapsed,
            isRightCollapsed: $isRightCollapsed,
            showKeyboardShortcuts: $showKeyboardShortcuts,
            showSessionHistory: $showSessionHistory
        ))
        .sheet(isPresented: $showKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: $showSessionHistory) {
            SessionHistoryView(sessionManager: sessionManager)
        }
        .errorAlert()
        .onDisappear {
            sessionManager.saveAllSessions()
            ctoEventBridge.stop()
        }
        .onChange(of: sessionManager.activeSessionId) { _ in
            connectParsers()
        }
    }

    @ToolbarContentBuilder
    private func makeToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { isLeftCollapsed.toggle() }) {
                Image(systemName: isLeftCollapsed ? "sidebar.left" : "sidebar.left.fill")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { isRightCollapsed.toggle() }) {
                Image(systemName: isRightCollapsed ? "sidebar.right" : "sidebar.right.fill")
            }
        }
    }

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

}

// MARK: - Notification Modifier

struct NotificationModifier: ViewModifier {
    @ObservedObject var sessionManager: ShellSessionManager
    @ObservedObject var editorManager: EditorManager
    @Binding var isLeftCollapsed: Bool
    @Binding var isRightCollapsed: Bool
    @Binding var showKeyboardShortcuts: Bool
    @Binding var showSessionHistory: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .toggleClaudeMode)) { _ in
                sessionManager.toggleClaudeMode()
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchClaude)) { _ in
                sessionManager.launchClaude()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exitClaude)) { _ in
                sessionManager.exitClaude()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
                editorManager.saveActiveFile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveAll)) { _ in
                editorManager.saveAll()
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeFile)) { _ in
                if let file = editorManager.activeFile {
                    editorManager.closeFile(file)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleFileBrowser)) { _ in
                isLeftCollapsed.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleKanban)) { _ in
                isRightCollapsed.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
                showKeyboardShortcuts = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showSessionHistory)) { _ in
                showSessionHistory = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearTerminal)) { _ in
                sessionManager.sendInput("clear\n")
            }
            .onReceive(NotificationCenter.default.publisher(for: .interruptProcess)) { _ in
                sessionManager.sendInput("\u{03}")
            }
    }
}

// MARK: - Drag Handle (AppKit-based to avoid SwiftUI update loops)

struct DragHandle: View {
    @Binding var value: CGFloat
    let min: CGFloat
    let max: CGFloat
    var axis: Axis = .horizontal
    var invert: Bool = false
    var onEnd: () -> Void = {}

    enum Axis { case horizontal, vertical }

    var body: some View {
        DragHandleRepresentable(
            axis: axis,
            onDrag: { delta in
                let newValue = value + (invert ? -delta : delta)
                value = Swift.min(max, Swift.max(min, newValue))
            },
            onEnd: onEnd
        )
        .frame(width: axis == .horizontal ? 1 : nil, height: axis == .vertical ? 1 : nil)
    }
}

struct DragHandleRepresentable: NSViewRepresentable {
    let axis: DragHandle.Axis
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> DragHandleNSView {
        let view = DragHandleNSView()
        view.axis = axis
        view.onDrag = onDrag
        view.onEnd = onEnd
        return view
    }

    func updateNSView(_ nsView: DragHandleNSView, context: Context) {
        nsView.onDrag = onDrag
        nsView.onEnd = onEnd
    }
}

class DragHandleNSView: NSView {
    var axis: DragHandle.Axis = .horizontal
    var onDrag: ((CGFloat) -> Void)?
    var onEnd: (() -> Void)?

    private var isDragging = false
    private var lastPoint: NSPoint = .zero
    private var trackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        // Visual size only - 1px
        axis == .horizontal
            ? NSSize(width: 1, height: NSView.noIntrinsicMetric)
            : NSSize(width: NSView.noIntrinsicMetric, height: 1)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        // Expanded tracking area for easier grabbing
        let expansion: CGFloat = 4
        let expandedRect: NSRect
        if axis == .horizontal {
            expandedRect = bounds.insetBy(dx: -expansion, dy: 0)
        } else {
            expandedRect = bounds.insetBy(dx: 0, dy: -expansion)
        }
        trackingArea = NSTrackingArea(
            rect: expandedRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        let color = isDragging ? NSColor.systemGreen.withAlphaComponent(0.6) : NSColor.separatorColor
        color.setFill()
        bounds.fill()
    }

    override func resetCursorRects() {
        let cursor: NSCursor = axis == .horizontal ? .resizeLeftRight : .resizeUpDown
        // Expanded cursor rect
        let expansion: CGFloat = 4
        let expandedRect = axis == .horizontal
            ? bounds.insetBy(dx: -expansion, dy: 0)
            : bounds.insetBy(dx: 0, dy: -expansion)
        addCursorRect(expandedRect, cursor: cursor)
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        lastPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentPoint = event.locationInWindow
        let delta = axis == .horizontal ? currentPoint.x - lastPoint.x : currentPoint.y - lastPoint.y
        lastPoint = currentPoint
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        needsDisplay = true
        onEnd?()
    }
}

// MARK: - Right Panel View

struct RightPanelView: View {
    @ObservedObject var kanbanManager: KanbanManager
    @ObservedObject var agentColumnsManager: AgentColumnsManager
    @Binding var isAgentCollapsed: Bool
    @Binding var agentHeight: CGFloat
    var onAgentHeightChange: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Kanban Board
            KanbanBoardView(
                board: kanbanManager.board,
                bridge: kanbanManager.bridge
            )
            .frame(maxHeight: .infinity)

            // Divider with toggle and drag
            agentDivider

            // Agent Columns
            AgentColumnsContainer(
                manager: agentColumnsManager,
                containerHeight: agentHeight,
                isCollapsed: isAgentCollapsed,
                onToggleCollapse: { isAgentCollapsed.toggle() }
            )
            .frame(height: isAgentCollapsed ? 36 : agentHeight)
        }
    }

    private var agentDivider: some View {
        // Just the drag handle - AgentColumnsContainer has its own header
        DragHandle(
            value: $agentHeight,
            min: 100, max: 400,
            axis: .vertical,
            onEnd: onAgentHeightChange
        )
        .opacity(isAgentCollapsed ? 0 : 1)
    }
}

// MARK: - Center Panel View

struct CenterPanelView: View {
    @ObservedObject var sessionManager: ShellSessionManager
    @ObservedObject var editorManager: EditorManager
    @ObservedObject var claudeProgressManager: ClaudeProgressManager
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                tabBar
                Divider().background(Color.rtBorderSubtle)

                if showEditor {
                    EditorPanelView(editorManager: editorManager)
                } else {
                    ContentView(sessionManager: sessionManager)
                }
            }

            if !showEditor && sessionManager.claudeMode {
                VStack {
                    Spacer().frame(height: 50)
                    ClaudeProgressOverlay(progressManager: claudeProgressManager)
                    Spacer()
                }
            }
        }
        .onChange(of: editorManager.activeFileId) { newValue in
            if newValue != nil { showEditor = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTerminal)) { _ in
            showEditor = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToEditor)) { _ in
            showEditor = true
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Terminal", icon: "terminal", isActive: !showEditor) {
                showEditor = false
            }
            tabButton(title: "Editor", icon: "doc.text", isActive: showEditor, badge: editorManager.hasUnsavedChanges) {
                showEditor = true
            }
            Spacer()
        }
        .background(Color.rtBackgroundLight)
    }

    private func tabButton(title: String, icon: String, isActive: Bool, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, design: .monospaced))
                if badge {
                    Circle().fill(Color.rtAccentGreen).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.rtBackgroundDark : Color.clear)
            .foregroundColor(isActive ? .rtTextPrimary : .rtTextSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .frame(width: 1200, height: 800)
    }
}
