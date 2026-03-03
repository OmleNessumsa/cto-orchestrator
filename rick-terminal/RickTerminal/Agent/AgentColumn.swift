import Foundation
import SwiftUI
import Combine

// MARK: - Agent Action

/// Individual action log entry for the scrolling activity feed
struct AgentAction: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let toolType: ClaudeToolType
    let description: String
    let status: ActionStatus

    /// Status of the action
    enum ActionStatus: String, Codable {
        case started
        case completed
        case failed
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        toolType: ClaudeToolType,
        description: String,
        status: ActionStatus = .started
    ) {
        self.id = id
        self.timestamp = timestamp
        self.toolType = toolType
        self.description = description
        self.status = status
    }

    /// Create from ClaudeToolEvent
    static func from(_ event: ClaudeToolEvent) -> AgentAction {
        let status: ActionStatus
        switch event.status {
        case .started, .executing:
            status = .started
        case .completed:
            status = .completed
        case .failed, .cancelled:
            status = .failed
        }

        return AgentAction(
            id: event.id,
            timestamp: event.timestamp,
            toolType: event.toolType,
            description: event.toolType.shortDescription,
            status: status
        )
    }

    // MARK: - Display Properties

    /// Formatted timestamp (HH:mm:ss)
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// Status icon name
    var statusIconName: String {
        switch status {
        case .started:
            return "arrow.right.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        }
    }

    /// Status color
    var statusColor: Color {
        switch status {
        case .started:
            return Color(hex: "2196F3")  // Blue
        case .completed:
            return .rtAccentGreen
        case .failed:
            return Color(hex: "F44336")  // Red
        }
    }
}

// MARK: - Agent Column

/// Observable state for a single active agent's visualization column
final class AgentColumn: Identifiable, ObservableObject {
    /// Unique identifier (matches agentId from ClaudeToolEvent)
    let id: UUID

    /// Agent type/role
    let role: AgentRole

    /// Human-readable display name
    @Published var displayName: String

    /// Active task description
    @Published var currentTask: String?

    /// Current lifecycle status
    @Published var status: AgentStatus

    /// Recent action log (capped)
    @Published private(set) var actions: [AgentAction]

    /// When the agent was spawned
    let spawnedAt: Date

    /// When the agent completed (if done)
    @Published var completedAt: Date?

    /// Lifecycle flag: appearing animation in progress
    @Published var isAppearing: Bool = true

    /// Lifecycle flag: disappearing animation in progress
    @Published var isDisappearing: Bool = false

    /// Maximum number of actions to retain
    var maxActions: Int = 50

    // MARK: - Initialization

    init(
        id: UUID,
        role: AgentRole,
        displayName: String? = nil,
        currentTask: String? = nil,
        status: AgentStatus = .spawning,
        actions: [AgentAction] = [],
        spawnedAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.displayName = displayName ?? role.mortyName
        self.currentTask = currentTask
        self.status = status
        self.actions = actions
        self.spawnedAt = spawnedAt
    }

    /// Create from Task tool event
    static func from(_ event: ClaudeToolEvent) -> AgentColumn? {
        guard case .task(let description, let agentType) = event.toolType else {
            return nil
        }

        let role = AgentRole(from: agentType)
        let agentId = event.agentId ?? event.id  // Use event id if no agentId

        return AgentColumn(
            id: agentId,
            role: role,
            currentTask: description,
            status: .spawning
        )
    }

    // MARK: - Action Management

    /// Add a new action to the log
    func addAction(_ action: AgentAction) {
        // Update status based on action
        if action.status == .started {
            status = .working
        }

        // Add to front (most recent first)
        actions.insert(action, at: 0)

        // Trim if over limit
        if actions.count > maxActions {
            actions = Array(actions.prefix(maxActions))
        }
    }

    /// Update an existing action's status
    func updateAction(id: UUID, status: AgentAction.ActionStatus) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else {
            return
        }

        let existing = actions[index]
        actions[index] = AgentAction(
            id: existing.id,
            timestamp: existing.timestamp,
            toolType: existing.toolType,
            description: existing.description,
            status: status
        )

        // If completed and no other active actions, set idle
        if status == .completed || status == .failed {
            let hasActiveActions = actions.contains { $0.status == .started }
            if !hasActiveActions && self.status == .working {
                self.status = .idle
            }
        }
    }

    /// Handle a tool event for this agent
    func handleEvent(_ event: ClaudeToolEvent) {
        switch event.status {
        case .started:
            let action = AgentAction.from(event)
            addAction(action)
            status = .working

        case .executing:
            // Update current action if exists
            status = .working

        case .completed:
            updateAction(id: event.id, status: .completed)
            // Check if task completed
            if case .task = event.toolType {
                markComplete()
            }

        case .failed:
            updateAction(id: event.id, status: .failed)
            // Check if task failed
            if case .task = event.toolType {
                markError()
            }

        case .cancelled:
            updateAction(id: event.id, status: .failed)
        }
    }

    // MARK: - Lifecycle

    /// Mark agent as completed
    func markComplete() {
        status = .done
        completedAt = Date()
    }

    /// Mark agent as errored
    func markError() {
        status = .error
        completedAt = Date()
    }

    /// Trigger appear animation completion
    func finishAppearing() {
        isAppearing = false
        if status == .spawning {
            status = .working
        }
    }

    /// Trigger disappear animation
    func startDisappearing() {
        isDisappearing = true
    }

    // MARK: - Computed Properties

    /// Duration since spawn
    var activeTime: TimeInterval {
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(spawnedAt)
    }

    /// Formatted active time
    var formattedActiveTime: String {
        let duration = Int(activeTime)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Count of completed actions
    var completedActionCount: Int {
        actions.filter { $0.status == .completed }.count
    }

    /// Count of failed actions
    var failedActionCount: Int {
        actions.filter { $0.status == .failed }.count
    }

    /// Most recent action (if any)
    var latestAction: AgentAction? {
        actions.first
    }
}

// MARK: - Equatable

extension AgentColumn: Equatable {
    static func == (lhs: AgentColumn, rhs: AgentColumn) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension AgentColumn: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
