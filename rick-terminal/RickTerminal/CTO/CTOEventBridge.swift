import Foundation
import Combine

// MARK: - CTO Event Bridge

/// Bridges CTO-Orchestrator events to Kanban and Agent visualizations
/// Connects RoroWebhookClient events to KanbanManager and AgentColumnsManager
final class CTOEventBridge: ObservableObject {

    // MARK: - Published Properties

    /// Whether the bridge is connected and listening
    @Published private(set) var isConnected = false

    /// Number of processed events
    @Published private(set) var processedEventCount = 0

    /// Last processed event type (for debugging)
    @Published private(set) var lastEventType: String?

    // MARK: - Private Properties

    private let webhookClient: RoroWebhookClient
    private weak var kanbanManager: KanbanManager?
    private weak var agentColumnsManager: AgentColumnsManager?
    private var cancellables = Set<AnyCancellable>()

    /// Track ticket IDs to card IDs for updates
    private var ticketToCardId: [String: UUID] = [:]

    /// Track agent names to column IDs
    private var agentToColumnId: [String: UUID] = [:]

    // MARK: - Initialization

    init(port: UInt16 = 3068) {
        self.webhookClient = RoroWebhookClient(port: port)

        // Subscribe to connection state
        webhookClient.$isListening
            .assign(to: &$isConnected)
    }

    deinit {
        stop()
    }

    // MARK: - Connection Management

    /// Connect the bridge to managers
    func connect(kanban: KanbanManager, agents: AgentColumnsManager) {
        self.kanbanManager = kanban
        self.agentColumnsManager = agents

        // Subscribe to webhook events
        webhookClient.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Start listening for events
    func start() {
        webhookClient.start()
    }

    /// Stop listening for events
    func stop() {
        webhookClient.stop()
        cancellables.removeAll()
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: CTOEvent) {
        processedEventCount += 1
        lastEventType = event.eventType

        switch event.eventType {
        // Ticket events → Kanban cards
        case CTOEventType.ticketCreated:
            createKanbanCard(from: event)

        case CTOEventType.ticketStatusChanged:
            updateKanbanCardStatus(from: event)

        case CTOEventType.ticketCompleted:
            completeKanbanCard(from: event)

        case CTOEventType.ticketBlocked:
            blockKanbanCard(from: event)

        case CTOEventType.ticketAssigned:
            assignKanbanCard(from: event)

        // Morty delegation events → Agent columns
        case CTOEventType.mortyDelegationStarted:
            createAgentColumn(from: event)

        case CTOEventType.mortyDelegationCompleted:
            completeAgentColumn(from: event, success: true)

        case CTOEventType.mortyDelegationFailed,
             CTOEventType.mortyDelegationTimeout:
            completeAgentColumn(from: event, success: false)

        default:
            // Log unhandled events for debugging
            print("[CTOEventBridge] Unhandled event: \(event.eventType)")
        }
    }

    // MARK: - Kanban Integration

    /// Create a Kanban card from a ticket creation event
    private func createKanbanCard(from event: CTOEvent) {
        guard let ticketId = event.data.ticketId,
              let title = event.data.title else {
            print("[CTOEventBridge] Missing ticket data for card creation")
            return
        }

        // Create label based on ticket type
        let label = labelForTicketType(event.data.type)

        // Map priority
        let priority = mapPriority(event.data.priority)

        // Create the card
        let card = KanbanCard(
            title: "[\(ticketId)] \(title)",
            description: "",
            status: .backlog,
            labels: label != nil ? [label!] : [],
            priority: priority,
            ticketRef: ticketId,
            source: .ticket(ref: ticketId)
        )

        // Store mapping
        ticketToCardId[ticketId] = card.id

        // Add to backlog column
        if let backlogColumn = findColumn(forStatus: .backlog) {
            kanbanManager?.board.addCard(card, to: backlogColumn.id)
            print("[CTOEventBridge] Created card for ticket \(ticketId)")
        }
    }

    /// Update a Kanban card's status based on ticket status change
    private func updateKanbanCardStatus(from event: CTOEvent) {
        guard let ticketId = event.data.ticketId,
              let newStatus = event.data.newStatus,
              let cardId = ticketToCardId[ticketId] else {
            return
        }

        guard let (card, currentColumnId) = kanbanManager?.board.findCard(id: cardId) else {
            return
        }

        // Map CTO status to CardStatus
        let targetStatus = mapTicketStatus(newStatus)

        // Find target column
        guard let targetColumn = findColumn(forStatus: targetStatus) else {
            return
        }

        // Move card if column changed
        if currentColumnId != targetColumn.id {
            kanbanManager?.board.moveCard(cardId, from: currentColumnId, to: targetColumn.id)
            print("[CTOEventBridge] Moved card \(ticketId) to \(targetStatus.displayName)")
        }
    }

    /// Mark a Kanban card as completed
    private func completeKanbanCard(from event: CTOEvent) {
        guard let ticketId = event.data.ticketId,
              let cardId = ticketToCardId[ticketId] else {
            return
        }

        guard let (_, currentColumnId) = kanbanManager?.board.findCard(id: cardId) else {
            return
        }

        // Find done column
        guard let doneColumn = findColumn(forStatus: .done) else {
            return
        }

        if currentColumnId != doneColumn.id {
            kanbanManager?.board.moveCard(cardId, from: currentColumnId, to: doneColumn.id)
            print("[CTOEventBridge] Completed card \(ticketId)")
        }
    }

    /// Mark a Kanban card as blocked
    private func blockKanbanCard(from event: CTOEvent) {
        guard let ticketId = event.data.ticketId,
              let cardId = ticketToCardId[ticketId] else {
            return
        }

        guard let (_, currentColumnId) = kanbanManager?.board.findCard(id: cardId) else {
            return
        }

        // Find blocked column (if exists)
        if let blockedColumn = findColumn(forStatus: .blocked) {
            if currentColumnId != blockedColumn.id {
                kanbanManager?.board.moveCard(cardId, from: currentColumnId, to: blockedColumn.id)
                print("[CTOEventBridge] Blocked card \(ticketId)")
            }
        }
    }

    /// Assign a Kanban card to an agent
    private func assignKanbanCard(from event: CTOEvent) {
        guard let ticketId = event.data.ticketId,
              let assignedAgent = event.data.assignedAgent,
              let cardId = ticketToCardId[ticketId] else {
            return
        }

        guard let (card, columnId) = kanbanManager?.board.findCard(id: cardId) else {
            return
        }

        let updatedCard = card.assignedTo(assignedAgent)
        kanbanManager?.board.updateCard(updatedCard, in: columnId)
        print("[CTOEventBridge] Assigned card \(ticketId) to \(assignedAgent)")
    }

    // MARK: - Agent Column Integration

    /// Create an agent column from a delegation start event
    private func createAgentColumn(from event: CTOEvent) {
        guard let agent = event.data.agent else {
            return
        }

        // Create synthetic ClaudeToolEvent for AgentColumnsManager
        let taskDescription = event.data.ticketId.map { "Working on \($0)" } ?? "Delegated task"
        let toolEvent = ClaudeToolEvent(
            toolType: .task(description: taskDescription, agentType: agent),
            status: .started,
            sessionId: UUID()
        )

        // Store mapping
        agentToColumnId[agent] = toolEvent.id

        // Let AgentColumnsManager handle the event
        agentColumnsManager?.handleEvent(toolEvent)
        print("[CTOEventBridge] Created agent column for \(agent)")
    }

    /// Mark an agent column as complete
    private func completeAgentColumn(from event: CTOEvent, success: Bool) {
        guard let agent = event.data.agent,
              let columnId = agentToColumnId[agent] else {
            return
        }

        // Create completion event
        let result: ToolResult = success
            ? .success(output: event.data.result)
            : .success(output: event.data.error ?? "Failed")

        let toolEvent = ClaudeToolEvent(
            id: columnId,
            toolType: .task(description: "", agentType: agent),
            status: success ? .completed(result: result) : .failed(error: event.data.error ?? "Unknown error"),
            sessionId: UUID()
        )

        agentColumnsManager?.handleEvent(toolEvent)
        print("[CTOEventBridge] Completed agent column for \(agent) (success: \(success))")

        // Clean up mapping
        agentToColumnId.removeValue(forKey: agent)
    }

    // MARK: - Helper Methods

    /// Find a Kanban column for a given card status
    private func findColumn(forStatus status: CardStatus) -> KanbanColumn? {
        guard let board = kanbanManager?.board else { return nil }

        // Match by status keyword in title
        let statusKeyword: String
        switch status {
        case .backlog:
            statusKeyword = "backlog"
        case .inProgress:
            statusKeyword = "progress"
        case .review:
            statusKeyword = "review"
        case .done:
            statusKeyword = "done"
        case .blocked:
            statusKeyword = "blocked"
        }

        return board.columns.first { column in
            column.title.lowercased().contains(statusKeyword)
        }
    }

    /// Create a CardLabel from ticket type
    private func labelForTicketType(_ type: String?) -> CardLabel? {
        guard let type = type?.lowercased() else { return nil }

        switch type {
        case "bug", "defect":
            return CardLabel.bug
        case "feature", "enhancement":
            return CardLabel.feature
        case "techdebt", "tech_debt", "refactor":
            return CardLabel.techDebt
        case "docs", "documentation":
            return CardLabel.docs
        case "test", "testing":
            return CardLabel.testing
        default:
            // Create custom label
            return CardLabel(name: type.capitalized, color: "#1E88E5")
        }
    }

    /// Map priority string to CardPriority
    private func mapPriority(_ priority: String?) -> CardPriority {
        guard let priority = priority?.lowercased() else { return .medium }

        switch priority {
        case "critical", "urgent":
            return .critical
        case "high":
            return .high
        case "low":
            return .low
        default:
            return .medium
        }
    }

    /// Map CTO ticket status to CardStatus
    private func mapTicketStatus(_ status: String) -> CardStatus {
        switch status.lowercased() {
        case "backlog", "todo", "open":
            return .backlog
        case "in_progress", "inprogress", "working":
            return .inProgress
        case "review", "testing":
            return .review
        case "done", "completed", "closed":
            return .done
        case "blocked":
            return .blocked
        default:
            return .backlog
        }
    }

    // MARK: - Debug Support

    #if DEBUG
    /// Simulate receiving an event (for testing)
    func simulateEvent(_ event: CTOEvent) {
        handleEvent(event)
    }

    /// Get current state summary
    var debugSummary: String {
        """
        Connected: \(isConnected)
        Events processed: \(processedEventCount)
        Last event: \(lastEventType ?? "none")
        Tracked tickets: \(ticketToCardId.count)
        Tracked agents: \(agentToColumnId.count)
        """
    }
    #endif
}
