import Foundation
import Combine

// MARK: - Bridge Delegate

/// Delegate protocol for receiving Kanban bridge events
protocol KanbanEventBridgeDelegate: AnyObject {
    /// Called when a new card is created from a Claude event
    func bridge(_ bridge: KanbanEventBridge, didCreateCard card: KanbanCard, in columnId: UUID)

    /// Called when an existing card is updated
    func bridge(_ bridge: KanbanEventBridge, didUpdateCard card: KanbanCard, in columnId: UUID)

    /// Called when a card is moved between columns
    func bridge(_ bridge: KanbanEventBridge, didMoveCard cardId: UUID, from sourceColumnId: UUID, to targetColumnId: UUID)

    /// Called when a sub-agent task creates a card
    func bridge(_ bridge: KanbanEventBridge, didCreateAgentCard card: KanbanCard, for agentId: UUID)
}

// MARK: - Default Delegate Implementation

extension KanbanEventBridgeDelegate {
    func bridge(_ bridge: KanbanEventBridge, didCreateCard card: KanbanCard, in columnId: UUID) {}
    func bridge(_ bridge: KanbanEventBridge, didUpdateCard card: KanbanCard, in columnId: UUID) {}
    func bridge(_ bridge: KanbanEventBridge, didMoveCard cardId: UUID, from sourceColumnId: UUID, to targetColumnId: UUID) {}
    func bridge(_ bridge: KanbanEventBridge, didCreateAgentCard card: KanbanCard, for agentId: UUID) {}
}

// MARK: - Kanban Event Bridge

/// Bridges Claude tool events to Kanban board updates
///
/// Responsibilities:
/// - Subscribe to ClaudeOutputParser events
/// - Parse TodoWrite payloads
/// - Create/update/move KanbanCards based on todo status
/// - Track known todos to prevent duplicates
/// - Preserve manual user changes
///
/// Usage:
/// ```swift
/// let bridge = KanbanEventBridge(board: kanbanBoard)
/// bridge.delegate = self
/// bridge.subscribe(to: outputParser)
/// ```
final class KanbanEventBridge: ObservableObject {

    // MARK: - Published Properties

    /// Number of cards created by this bridge
    @Published private(set) var cardsCreated: Int = 0

    /// Number of cards updated by this bridge
    @Published private(set) var cardsUpdated: Int = 0

    /// Last sync timestamp
    @Published private(set) var lastSyncAt: Date?

    // MARK: - Configuration

    /// Delegate for bridge events
    weak var delegate: KanbanEventBridgeDelegate?

    /// The Kanban board being updated
    let board: KanbanBoard

    /// Whether to auto-create cards for sub-agent tasks
    var trackSubAgentTasks: Bool = true

    /// Label to apply to auto-created cards
    var autoCreatedLabel: CardLabel = CardLabel(name: "Auto", color: "#9E9E9E")

    // MARK: - Internal State

    /// Set of known content hashes (for duplicate detection)
    private var knownHashes: Set<String> = []

    /// Map from content hash to card ID (for updates)
    private var hashToCardId: [String: UUID] = [:]

    /// Cards that user has manually moved (don't auto-move)
    private var manuallyMovedCards: Set<UUID> = []

    /// Cards that user has claimed as manual
    private var manualCards: Set<UUID> = []

    /// Map from agent ID to their task card
    private var agentTaskCards: [UUID: UUID] = [:]

    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Thread-safe queue for state updates
    private let stateQueue = DispatchQueue(
        label: "com.rick.terminal.kanban.bridge",
        qos: .userInitiated
    )

    // MARK: - Initialization

    init(board: KanbanBoard) {
        self.board = board
        loadExistingCardHashes()
    }

    // MARK: - Subscription

    /// Subscribe to a ClaudeOutputParser's event stream
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

    // MARK: - Event Handling

    /// Handle a Claude tool event
    func handleEvent(_ event: ClaudeToolEvent) {
        switch event.toolType {
        case .todoWrite:
            handleTodoWrite(event)

        case .task:
            if trackSubAgentTasks {
                handleTaskEvent(event)
            }

        default:
            // Other tool types don't affect Kanban directly
            break
        }
    }

    // MARK: - TodoWrite Handling

    private func handleTodoWrite(_ event: ClaudeToolEvent) {
        guard let payload = event.todoWritePayload else {
            return
        }

        for todo in payload.todos {
            processTodoItem(todo, agentId: event.agentId)
        }

        lastSyncAt = Date()
    }

    private func processTodoItem(_ todo: TodoItem, agentId: UUID?) {
        let hash = todo.sourceHash

        // Check if we've seen this todo before
        if knownHashes.contains(hash) {
            // Update existing card
            if let cardId = hashToCardId[hash] {
                updateExistingCard(cardId: cardId, with: todo)
            }
        } else {
            // Create new card
            createNewCard(from: todo, agentId: agentId)
            knownHashes.insert(hash)
        }
    }

    private func createNewCard(from todo: TodoItem, agentId: UUID?) {
        // Determine target column based on status
        guard let targetColumn = column(for: todo.status.cardStatus) else {
            return
        }

        // Create card
        var card = todo.toKanbanCard(agentId: agentId)
        card.labels.append(autoCreatedLabel)

        // Add to board
        board.addCard(card, to: targetColumn.id)

        // Track mapping
        hashToCardId[todo.sourceHash] = card.id

        // Update stats
        cardsCreated += 1

        // Notify delegate
        delegate?.bridge(self, didCreateCard: card, in: targetColumn.id)
    }

    private func updateExistingCard(cardId: UUID, with todo: TodoItem) {
        // Don't update manual cards
        guard !manualCards.contains(cardId) else {
            return
        }

        guard let (existingCard, columnId) = board.findCard(id: cardId) else {
            return
        }

        // Check if source is Claude (not manual)
        guard !existingCard.source.isManual else {
            return
        }

        let targetStatus = todo.status.cardStatus

        // Check if status changed
        if existingCard.status != targetStatus {
            // Don't move if user has manually moved this card
            guard !manuallyMovedCards.contains(cardId) else {
                // Still update title/description if changed
                updateCardContent(cardId: cardId, in: columnId, with: todo)
                return
            }

            // Move to appropriate column
            if let targetColumn = column(for: targetStatus) {
                board.moveCard(cardId, from: columnId, to: targetColumn.id)

                cardsUpdated += 1
                delegate?.bridge(self, didMoveCard: cardId, from: columnId, to: targetColumn.id)
            }
        }

        // Update content if changed
        updateCardContent(cardId: cardId, in: board.findCard(id: cardId)?.1 ?? columnId, with: todo)
    }

    private func updateCardContent(cardId: UUID, in columnId: UUID, with todo: TodoItem) {
        guard let (existingCard, _) = board.findCard(id: cardId) else {
            return
        }

        // Only update if content actually changed
        if existingCard.title != todo.content {
            var updatedCard = existingCard
            updatedCard.title = todo.content
            updatedCard.updatedAt = Date()

            board.updateCard(updatedCard, in: columnId)
            delegate?.bridge(self, didUpdateCard: updatedCard, in: columnId)
        }
    }

    // MARK: - Sub-Agent Task Handling

    private func handleTaskEvent(_ event: ClaudeToolEvent) {
        guard case .task(let description, let agentType) = event.toolType else {
            return
        }

        switch event.status {
        case .started:
            createAgentTaskCard(description: description, agentType: agentType, event: event)

        case .completed:
            completeAgentTask(eventId: event.id)

        case .failed, .cancelled:
            failAgentTask(eventId: event.id)

        default:
            break
        }
    }

    private func createAgentTaskCard(description: String, agentType: String?, event: ClaudeToolEvent) {
        let agentId = event.agentId ?? event.id
        let hash = computeTaskHash(description: description, agentType: agentType)

        // Skip if already tracking this task
        guard !knownHashes.contains(hash) else {
            return
        }

        guard let inProgressColumn = column(for: .inProgress) else {
            return
        }

        // Create card for agent task
        var card = KanbanCard(
            title: description,
            description: "Sub-agent task: \(agentType ?? "general")",
            status: .inProgress,
            labels: [CardLabel(name: "Agent", color: "#9C27B0"), autoCreatedLabel],
            priority: .medium,
            assignee: agentId.uuidString
        )
        card.source = .subAgent(agentId: agentId, taskHash: hash)

        // Add to board
        board.addCard(card, to: inProgressColumn.id)

        // Track
        knownHashes.insert(hash)
        hashToCardId[hash] = card.id
        agentTaskCards[agentId] = card.id
        cardsCreated += 1

        delegate?.bridge(self, didCreateAgentCard: card, for: agentId)
    }

    private func completeAgentTask(eventId: UUID) {
        guard let cardId = agentTaskCards[eventId] ?? findAgentCard(by: eventId) else {
            return
        }

        moveCardToDone(cardId)
    }

    private func failAgentTask(eventId: UUID) {
        guard let cardId = agentTaskCards[eventId] ?? findAgentCard(by: eventId) else {
            return
        }

        // Move to blocked or mark as failed
        guard let (card, columnId) = board.findCard(id: cardId) else {
            return
        }

        if let blockedColumn = board.columns.first(where: { $0.title.lowercased() == "blocked" }) {
            board.moveCard(cardId, from: columnId, to: blockedColumn.id)
            delegate?.bridge(self, didMoveCard: cardId, from: columnId, to: blockedColumn.id)
        } else {
            // Update status without moving
            var updatedCard = card.withStatus(.blocked)
            updatedCard.labels.append(CardLabel(name: "Failed", color: "#F44336"))
            board.updateCard(updatedCard, in: columnId)
            delegate?.bridge(self, didUpdateCard: updatedCard, in: columnId)
        }
    }

    private func moveCardToDone(_ cardId: UUID) {
        guard let (_, columnId) = board.findCard(id: cardId) else {
            return
        }

        guard let doneColumn = column(for: .done) else {
            return
        }

        board.moveCard(cardId, from: columnId, to: doneColumn.id)
        cardsUpdated += 1
        delegate?.bridge(self, didMoveCard: cardId, from: columnId, to: doneColumn.id)
    }

    private func findAgentCard(by eventId: UUID) -> UUID? {
        for card in board.allCards {
            if case .subAgent(let agentId, _) = card.source, agentId == eventId {
                return card.id
            }
        }
        return nil
    }

    // MARK: - Manual Change Tracking

    /// Mark a card as manually managed (won't be auto-updated)
    func markAsManual(_ cardId: UUID) {
        manualCards.insert(cardId)

        // Also update the card's source
        if let (card, columnId) = board.findCard(id: cardId) {
            var updatedCard = card
            updatedCard.source = .manual
            board.updateCard(updatedCard, in: columnId)
        }
    }

    /// Record that user manually moved a card (prevent auto-move)
    func recordManualMove(_ cardId: UUID) {
        manuallyMovedCards.insert(cardId)
    }

    /// Check if a card is manually managed
    func isManualCard(_ cardId: UUID) -> Bool {
        manualCards.contains(cardId)
    }

    // MARK: - Helpers

    private func column(for status: CardStatus) -> KanbanColumn? {
        switch status {
        case .backlog:
            return board.columns.first { $0.title.lowercased().contains("backlog") }
                ?? board.columns.first

        case .inProgress:
            return board.columns.first { $0.title.lowercased().contains("progress") }
                ?? board.columns.dropFirst().first

        case .review:
            return board.columns.first { $0.title.lowercased().contains("review") }

        case .done:
            return board.columns.first { $0.title.lowercased().contains("done") }
                ?? board.columns.last

        case .blocked:
            return board.columns.first { $0.title.lowercased().contains("blocked") }
        }
    }

    private func computeTaskHash(description: String, agentType: String?) -> String {
        let input = "\(description.lowercased())-\(agentType?.lowercased() ?? "general")"
        return TodoItem.computeHash(content: input)
    }

    /// Load existing card hashes from board (for continuity across sessions)
    private func loadExistingCardHashes() {
        for card in board.allCards {
            if let hash = card.source.sourceHash {
                knownHashes.insert(hash)
                hashToCardId[hash] = card.id
            }

            if card.source.isManual {
                manualCards.insert(card.id)
            }
        }
    }

    // MARK: - Reset

    /// Reset bridge state (for new session)
    func reset() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }

            self.knownHashes.removeAll()
            self.hashToCardId.removeAll()
            self.manuallyMovedCards.removeAll()
            self.agentTaskCards.removeAll()

            DispatchQueue.main.async {
                self.cardsCreated = 0
                self.cardsUpdated = 0
                self.lastSyncAt = nil
            }
        }
    }
}

// MARK: - Board Card Event Integration

extension KanbanEventBridge {
    /// Subscribe to board card events to track manual changes
    func observeBoardChanges() {
        board.cardEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .moved(let cardId, _, _):
                    // Track as manually moved if not from bridge
                    self?.manuallyMovedCards.insert(cardId)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Debug Support

#if DEBUG
extension KanbanEventBridge {
    /// Create mock event for testing
    static func mockTodoWriteEvent(todos: [(String, TodoStatus)]) -> ClaudeToolEvent {
        let output = todos.map { content, status in
            """
            - content: "\(content)"
              status: \(status.rawValue)
              activeForm: "\(TodoWriteParser.toActiveForm(content))"
            """
        }.joined(separator: "\n")

        return ClaudeToolEvent(
            toolType: .todoWrite,
            status: .completed(result: .success(output: output)),
            sessionId: UUID(),
            rawOutput: output
        )
    }
}
#endif
