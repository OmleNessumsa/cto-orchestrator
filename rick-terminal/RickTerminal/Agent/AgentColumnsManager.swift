import Foundation
import SwiftUI
import Combine

// MARK: - Agent Columns Manager

/// Orchestrator that bridges ClaudeOutputParser events to column state
final class AgentColumnsManager: ObservableObject {

    // MARK: - Published Properties

    /// Active agent columns (ordered by spawn time)
    @Published private(set) var columns: [AgentColumn] = []

    // MARK: - Configuration

    /// Maximum actions retained per column
    var maxActionsPerColumn: Int = 50

    /// Delay before fading out completed columns (seconds)
    var columnFadeDelay: TimeInterval = 2.0

    /// Duration of fade animation (seconds)
    var fadeAnimationDuration: TimeInterval = 0.5

    /// Duration of appear animation (seconds)
    var appearAnimationDuration: TimeInterval = 0.3

    // MARK: - Private Properties

    /// Quick lookup by agent ID
    private var columnsByAgent: [UUID: AgentColumn] = [:]

    /// Subscriptions for Combine
    private var cancellables = Set<AnyCancellable>()

    /// Timer for cleanup tasks
    private var cleanupTimer: Timer?

    /// Queue for thread-safe operations
    private let updateQueue = DispatchQueue(
        label: "com.rick.terminal.agent.columns",
        qos: .userInteractive
    )

    // MARK: - Initialization

    init() {
        setupCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
        cancellables.removeAll()
    }

    // MARK: - Subscription

    /// Subscribe to parser events
    func subscribe(to parser: ClaudeOutputParser) {
        parser.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Unsubscribe from all parsers
    func unsubscribe() {
        cancellables.removeAll()
    }

    /// Clear all columns (used at app start to remove stale data)
    func clearAll() {
        columns.removeAll()
        columnsByAgent.removeAll()
    }

    // MARK: - Event Handling

    /// Handle a tool event from the parser
    func handleEvent(_ event: ClaudeToolEvent) {
        // Check if this is a Task tool (spawning new agent)
        if case .task = event.toolType, event.status == .started {
            createColumn(from: event)
            return
        }

        // Route to existing column if agentId matches
        if let agentId = event.agentId, let column = columnsByAgent[agentId] {
            column.handleEvent(event)
            objectWillChange.send()
            return
        }

        // Check if event ID matches a column (for task completion)
        if let column = columnsByAgent[event.id] {
            column.handleEvent(event)
            objectWillChange.send()

            // Schedule fade if terminal
            if column.status.isTerminal {
                scheduleFadeOut(for: column)
            }
        }
    }

    // MARK: - Column Management

    /// Create a new column from a Task event
    private func createColumn(from event: ClaudeToolEvent) {
        guard let column = AgentColumn.from(event) else {
            // Debug log
            let debugMsg = "[\(Date())] AgentColumnsManager: AgentColumn.from() returned nil\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
            return
        }

        column.maxActions = maxActionsPerColumn

        // Add to collections
        columnsByAgent[column.id] = column
        columns.append(column)

        // Force UI update
        objectWillChange.send()

        // Debug log
        let debugMsg = "[\(Date())] AgentColumnsManager: Created column '\(column.displayName)' (total: \(columns.count))\n"
        if let data = debugMsg.data(using: .utf8) {
            let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
            if let handle = try? FileHandle(forWritingTo: debugFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }

        // Trigger appear animation
        DispatchQueue.main.asyncAfter(deadline: .now() + appearAnimationDuration) { [weak column] in
            column?.finishAppearing()
        }
    }

    /// Get column for agent ID
    func columnForAgent(_ agentId: UUID) -> AgentColumn? {
        columnsByAgent[agentId]
    }

    /// Manually dismiss a column
    func dismissColumn(_ columnId: UUID) {
        guard let column = columnsByAgent[columnId] else {
            return
        }

        column.startDisappearing()

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeAnimationDuration) { [weak self] in
            self?.removeColumn(columnId)
        }
    }

    /// Remove a column from tracking
    private func removeColumn(_ columnId: UUID) {
        columnsByAgent.removeValue(forKey: columnId)
        columns.removeAll { $0.id == columnId }
    }

    /// Schedule fade-out for a completed column
    private func scheduleFadeOut(for column: AgentColumn) {
        DispatchQueue.main.asyncAfter(deadline: .now() + columnFadeDelay) { [weak self, weak column] in
            guard let self = self, let column = column else { return }

            column.startDisappearing()

            DispatchQueue.main.asyncAfter(deadline: .now() + self.fadeAnimationDuration) { [weak self] in
                self?.removeColumn(column.id)
            }
        }
    }

    // MARK: - Cleanup

    /// Setup periodic cleanup timer
    private func setupCleanupTimer() {
        // Clean up stale columns every 30 seconds
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.cleanupStaleColumns()
        }
    }

    /// Remove columns that have been completed for too long
    private func cleanupStaleColumns() {
        let now = Date()
        let staleThreshold: TimeInterval = 60.0  // 1 minute

        let staleColumns = columns.filter { column in
            guard let completedAt = column.completedAt else { return false }
            return now.timeIntervalSince(completedAt) > staleThreshold
        }

        for column in staleColumns {
            removeColumn(column.id)
        }
    }

    // MARK: - Computed Properties

    /// Number of active (non-terminal) columns
    var activeCount: Int {
        columns.filter { !$0.status.isTerminal }.count
    }

    /// All columns sorted by spawn time (oldest first)
    var sortedColumns: [AgentColumn] {
        columns.sorted { $0.spawnedAt < $1.spawnedAt }
    }

    /// All working columns
    var workingColumns: [AgentColumn] {
        columns.filter { $0.status == .working }
    }

    /// All completed columns (done or error)
    var completedColumns: [AgentColumn] {
        columns.filter { $0.status.isTerminal }
    }

    /// Whether any agents are currently active
    var hasActiveAgents: Bool {
        activeCount > 0
    }

    // MARK: - Debug Support

    #if DEBUG
    /// Create a mock column for testing
    func createMockColumn(role: AgentRole, task: String) -> AgentColumn {
        let column = AgentColumn(
            id: UUID(),
            role: role,
            currentTask: task,
            status: .working
        )
        column.maxActions = maxActionsPerColumn

        columnsByAgent[column.id] = column
        columns.append(column)

        return column
    }

    /// Add mock action to a column
    func addMockAction(to column: AgentColumn, toolType: ClaudeToolType) {
        let action = AgentAction(
            toolType: toolType,
            description: toolType.shortDescription,
            status: .completed
        )
        column.addAction(action)
        objectWillChange.send()
    }
    #endif
}

// MARK: - Preview Support

#if DEBUG
extension AgentColumnsManager {
    /// Create a manager with mock data for previews
    static var preview: AgentColumnsManager {
        let manager = AgentColumnsManager()

        // Create mock columns
        let architectColumn = manager.createMockColumn(
            role: .architect,
            task: "Designing system architecture"
        )
        manager.addMockAction(to: architectColumn, toolType: .read(path: "/src/models/User.swift"))
        manager.addMockAction(to: architectColumn, toolType: .grep(pattern: "protocol", path: nil))
        manager.addMockAction(to: architectColumn, toolType: .write(path: "/docs/adr/ADR-005.md"))

        let backendColumn = manager.createMockColumn(
            role: .backend,
            task: "Implementing API endpoints"
        )
        backendColumn.status = .working
        manager.addMockAction(to: backendColumn, toolType: .edit(path: "/src/api/routes.swift"))
        manager.addMockAction(to: backendColumn, toolType: .bash(command: "swift test"))

        let frontendColumn = manager.createMockColumn(
            role: .frontend,
            task: "Building UI components"
        )
        frontendColumn.status = .idle
        manager.addMockAction(to: frontendColumn, toolType: .read(path: "/src/views/ListView.swift"))

        return manager
    }
}
#endif
