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

    /// Number of tickets loaded from disk
    @Published private(set) var loadedTicketCount = 0

    /// Current project URL (for ticket loading)
    @Published private(set) var currentProjectURL: URL?

    // MARK: - Private Properties

    private let webhookClient: RoroWebhookClient
    private weak var kanbanManager: KanbanManager?
    private weak var agentColumnsManager: AgentColumnsManager?
    private var cancellables = Set<AnyCancellable>()

    /// Track ticket IDs to card IDs for updates
    private var ticketToCardId: [String: UUID] = [:]

    /// Track agent names to column IDs
    private var agentToColumnId: [String: UUID] = [:]

    /// File system watcher for ticket changes
    private var ticketWatcher: DispatchSourceFileSystemObject?

    /// Debounce work item for ticket reloading
    private var reloadWorkItem: DispatchWorkItem?

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

        NSLog("[CTOEventBridge] 🔌 Connecting to managers (kanban: %@, agents: %@)",
              kanban.board.title, String(describing: agents.columns.count))

        // Subscribe to webhook events
        webhookClient.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                // Debug: write to file
                let debugMsg = "[\(Date())] CTOEventBridge received: \(event.eventType)\n"
                if let data = debugMsg.data(using: .utf8) {
                    let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                    if let handle = try? FileHandle(forWritingTo: debugFile) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                }
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Start listening for events
    func start() {
        // Clear any stale mappings from previous sessions
        agentToColumnId.removeAll()

        NSLog("[CTOEventBridge] 🚀 Starting webhook client...")
        webhookClient.start()
    }

    /// Stop listening for events
    func stop() {
        webhookClient.stop()
        cancellables.removeAll()
        stopWatchingTickets()
    }

    // MARK: - Project Ticket Loading

    /// Load tickets from a project's .cto/tickets/ folder
    func loadProjectTickets(from projectURL: URL) {
        currentProjectURL = projectURL

        // Check if this is a CTO project
        let ctoDir = projectURL.appendingPathComponent(".cto")
        guard FileManager.default.fileExists(atPath: ctoDir.path) else {
            print("[CTOEventBridge] Not a CTO project: \(projectURL.path)")
            return
        }

        // Load tickets on background thread to avoid UI freeze
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tickets = CTOTicketLoader.loadTickets(from: projectURL)

            DispatchQueue.main.async {
                self?.processLoadedTickets(tickets, from: projectURL)
            }
        }
    }

    /// Process loaded tickets on the main thread
    private func processLoadedTickets(_ tickets: [CTOTicket], from projectURL: URL) {
        print("[CTOEventBridge] Processing \(tickets.count) tickets from \(projectURL.path)")

        guard let board = kanbanManager?.board else {
            print("[CTOEventBridge] ERROR: kanbanManager.board is nil!")
            return
        }

        // Clear ALL existing cards from the board before loading new project
        board.clearAllCards()

        // Clear existing ticket-to-card mappings
        ticketToCardId.removeAll()

        // Update count
        loadedTicketCount = tickets.count

        // Build batch of cards with their target columns
        var cardsToAdd: [(card: KanbanCard, columnId: UUID)] = []

        for ticket in tickets {
            let card = ticket.toKanbanCard()
            ticketToCardId[ticket.id] = card.id

            // Find appropriate column based on ticket status
            let targetColumn = findColumn(forStatus: ticket.status.cardStatus)
                ?? board.columns.first

            if let columnId = targetColumn?.id {
                cardsToAdd.append((card: card, columnId: columnId))
            }
        }

        // Add all cards at once (synchronous batch operation)
        board.addCards(cardsToAdd)

        print("[CTOEventBridge] Finished loading \(cardsToAdd.count) tickets")
    }

    /// Clear all cards from the kanban board
    private func clearAllCards() {
        guard let board = kanbanManager?.board else { return }

        // Use the synchronous clearAllCards method
        board.clearAllCards()

        print("[CTOEventBridge] Cleared all cards from board")
    }

    /// Reload tickets from the current project (debounced)
    func reloadTickets() {
        // Cancel any pending reload
        reloadWorkItem?.cancel()

        // If no project URL set, try to auto-detect
        var projectURL = currentProjectURL
        if projectURL == nil {
            projectURL = detectCTOProject()
        }

        guard let url = projectURL else {
            print("[CTOEventBridge] No CTO project found to reload")
            return
        }

        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.loadProjectTickets(from: url)
        }
        reloadWorkItem = workItem

        // Execute after debounce delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    /// Try to detect a CTO project - only uses current working directory
    private func detectCTOProject() -> URL? {
        // Only use current working directory - no fallbacks to prevent loading wrong project
        let currentDir = FileManager.default.currentDirectoryPath
        let currentURL = URL(fileURLWithPath: currentDir)

        if FileManager.default.fileExists(atPath: currentURL.appendingPathComponent(".cto").path) {
            print("[CTOEventBridge] Found CTO project at: \(currentURL.path)")
            return currentURL
        }

        print("[CTOEventBridge] No .cto folder in current directory: \(currentDir)")
        return nil
    }

    /// Add a single ticket to the Kanban board
    private func addTicketToKanban(_ ticket: CTOTicket) {
        guard let board = kanbanManager?.board else {
            print("[CTOEventBridge] ERROR: kanbanManager.board is nil!")
            return
        }

        // Check if card already exists for this ticket
        if let existingCard = board.card(withTicketRef: ticket.id) {
            // Update existing card if needed
            ticketToCardId[ticket.id] = existingCard.id
            print("[CTOEventBridge] Ticket \(ticket.id) already exists as card")
            return
        }

        // Create new card from ticket
        let card = ticket.toKanbanCard()
        ticketToCardId[ticket.id] = card.id

        // Find appropriate column based on ticket status
        let targetColumn = findColumn(forStatus: ticket.status.cardStatus)
            ?? board.columns.first

        if let columnId = targetColumn?.id {
            board.addCard(card, to: columnId)
            print("[CTOEventBridge] Added ticket \(ticket.id) to column \(targetColumn?.title ?? "unknown")")
        } else {
            print("[CTOEventBridge] ERROR: No column found for ticket \(ticket.id)")
        }
    }

    /// Start watching the tickets directory for changes
    private func startWatchingTickets(at projectURL: URL) {
        stopWatchingTickets()

        let ticketsDir = projectURL.appendingPathComponent(".cto/tickets")
        guard FileManager.default.fileExists(atPath: ticketsDir.path) else { return }

        let fd = open(ticketsDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        ticketWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )

        ticketWatcher?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.reloadTickets()
            }
        }

        ticketWatcher?.setCancelHandler {
            close(fd)
        }

        ticketWatcher?.resume()
        print("[CTOEventBridge] Watching tickets directory for changes")
    }

    /// Stop watching the tickets directory
    private func stopWatchingTickets() {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil
        ticketWatcher?.cancel()
        ticketWatcher = nil
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: CTOEvent) {
        processedEventCount += 1
        lastEventType = event.eventType

        NSLog("[CTOEventBridge] 🎯 Received event: %@", event.eventType)
        NSLog("[CTOEventBridge]    Agent: %@", event.agentId)
        NSLog("[CTOEventBridge]    Data: ticket=%@, agent=%@", event.data.ticketId ?? "nil", event.data.agent ?? "nil")

        switch event.eventType {
        // Ticket events → Kanban cards
        case CTOEventType.ticketCreated:
            createKanbanCard(from: event)

        case CTOEventType.ticketStatusChanged:
            // Debug log
            let debugMsg2 = "[\(Date())] Matched ticketStatusChanged, calling updateKanbanCardStatus\n"
            if let data = debugMsg2.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
            updateKanbanCardStatus(from: event)

        case CTOEventType.ticketCompleted:
            completeKanbanCard(from: event)

        case CTOEventType.ticketBlocked:
            blockKanbanCard(from: event)

        case CTOEventType.ticketAssigned:
            assignKanbanCard(from: event)

        // Morty delegation events → Agent columns
        case CTOEventType.mortyDelegationStarted:
            // Debug log
            let debugMsg = "[\(Date())] Matched mortyDelegationStarted, calling createAgentColumn\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
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
        // Debug helper
        func debugLog(_ msg: String) {
            let debugMsg = "[\(Date())] updateKanbanCardStatus: \(msg)\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
        }

        debugLog("Starting...")

        guard let ticketId = event.data.ticketId else {
            debugLog("No ticket_id in event")
            return
        }

        guard let newStatus = event.data.newStatus else {
            debugLog("No new_status in event for \(ticketId)")
            return
        }

        debugLog("Processing \(ticketId) → \(newStatus)")

        guard let cardId = ticketToCardId[ticketId] else {
            debugLog("No card mapping for ticket \(ticketId). Known tickets: \(Array(ticketToCardId.keys))")
            // Try to reload tickets to get fresh state
            reloadTickets()
            return
        }

        guard let (card, currentColumnId) = kanbanManager?.board.findCard(id: cardId) else {
            debugLog("Card \(cardId) not found on board")
            return
        }

        // Map CTO status to CardStatus
        let targetStatus = mapTicketStatus(newStatus)
        debugLog("\(ticketId): \(newStatus) → \(targetStatus.displayName)")

        // Find target column
        guard let targetColumn = findColumn(forStatus: targetStatus) else {
            debugLog("No column for status \(targetStatus)")
            return
        }

        // Move card if column changed
        if currentColumnId != targetColumn.id {
            kanbanManager?.board.moveCard(cardId, from: currentColumnId, to: targetColumn.id)
            debugLog("✅ Moved card \(ticketId) to \(targetColumn.title)")
        } else {
            debugLog("Card already in correct column")
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
        // Debug logging to file
        func debugLog(_ msg: String) {
            let debugMsg = "[\(Date())] \(msg)\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
        }

        guard let agent = event.data.agent else {
            debugLog("createAgentColumn: No agent in event data")
            return
        }

        debugLog("Creating agent column for: \(agent)")

        // Create synthetic ClaudeToolEvent for AgentColumnsManager
        let taskDescription = event.data.ticketId.map { "Working on \($0)" } ?? "Delegated task"
        let toolEvent = ClaudeToolEvent(
            toolType: .task(description: taskDescription, agentType: agent),
            status: .started,
            sessionId: UUID()
        )

        debugLog("Task: \(taskDescription), Tool event ID: \(toolEvent.id)")

        // Store mapping
        agentToColumnId[agent] = toolEvent.id

        // Let AgentColumnsManager handle the event
        if let manager = agentColumnsManager {
            let beforeCount = manager.columns.count
            manager.handleEvent(toolEvent)
            let afterCount = manager.columns.count
            debugLog("Sent to AgentColumnsManager (before: \(beforeCount), after: \(afterCount))")
        } else {
            debugLog("ERROR: AgentColumnsManager is nil!")
        }

        // Also move the ticket to "In Progress" when delegation starts
        if let ticketId = event.data.ticketId {
            debugLog("Moving ticket \(ticketId) to In Progress...")
            moveTicketToInProgress(ticketId: ticketId)
        }
    }

    /// Move a ticket to In Progress when a Morty starts working on it
    private func moveTicketToInProgress(ticketId: String) {
        func debugLog(_ msg: String) {
            let debugMsg = "[\(Date())] moveTicketToInProgress: \(msg)\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
        }

        guard let cardId = ticketToCardId[ticketId] else {
            debugLog("No card mapping for ticket \(ticketId)")
            return
        }

        guard let board = kanbanManager?.board,
              let (_, currentColumnId) = board.findCard(id: cardId) else {
            debugLog("Card not found on board")
            return
        }

        guard let inProgressColumn = findColumn(forStatus: .inProgress) else {
            debugLog("No In Progress column found")
            return
        }

        // Only move if not already in progress or done
        if currentColumnId != inProgressColumn.id {
            // Check if it's in a "done" column - don't move completed tickets back
            if let doneColumn = findColumn(forStatus: .done), currentColumnId == doneColumn.id {
                debugLog("Ticket already done, not moving back")
                return
            }

            board.moveCard(cardId, from: currentColumnId, to: inProgressColumn.id)
            debugLog("✅ Moved \(ticketId) to In Progress")
        } else {
            debugLog("Already in In Progress")
        }
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
