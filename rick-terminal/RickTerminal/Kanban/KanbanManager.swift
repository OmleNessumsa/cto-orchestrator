import Foundation
import Combine

// MARK: - Kanban Manager

/// Manages Kanban board and bridge lifecycle with persistence
final class KanbanManager: ObservableObject {
    @Published private(set) var board: KanbanBoard
    @Published private(set) var bridge: KanbanEventBridge

    private var cancellables = Set<AnyCancellable>()
    private let persistence = KanbanPersistenceManager.shared
    private let projectRef: String

    init(projectRef: String = "rick-terminal") {
        self.projectRef = projectRef

        // Always start with a fresh board - tickets are loaded from .cto/ when project is opened
        let initialBoard = KanbanBoard.standard(
            title: "Tasks",
            projectRef: projectRef
        )

        self.board = initialBoard
        self.bridge = KanbanEventBridge(board: initialBoard)

        // Enable bridge to observe board changes
        bridge.observeBoardChanges()

        // Note: Auto-save disabled - tickets come from .cto/tickets/ files
        // Manual cards could be persisted in the future if needed
    }

    /// Subscribe to parser events
    func subscribe(to parser: ClaudeOutputParser) {
        bridge.subscribe(to: parser)
    }

    /// Unsubscribe from all parsers
    func unsubscribe() {
        bridge.unsubscribe()
    }

    /// Claim a card (convert to manual)
    func claimCard(_ cardId: UUID) {
        bridge.markAsManual(cardId)
    }

    /// Add a new manual card
    func addCard(_ card: KanbanCard, to columnId: UUID) {
        var manualCard = card
        manualCard.source = .manual
        board.addCard(manualCard, to: columnId)
    }

    /// Remove a card
    func removeCard(id cardId: UUID, from columnId: UUID) {
        board.removeCard(id: cardId, from: columnId)
    }

    /// Move a card between columns
    func moveCard(_ cardId: UUID, from sourceColumnId: UUID, to targetColumnId: UUID) {
        board.moveCard(cardId, from: sourceColumnId, to: targetColumnId)
        bridge.recordManualMove(cardId)
    }

    /// Switch to a different board
    func switchBoard(_ newBoard: KanbanBoard) {
        // Stop observing old board
        persistence.stopObserving()

        // Update board and bridge
        board = newBoard
        bridge = KanbanEventBridge(board: newBoard)
        bridge.observeBoardChanges()

        // Save as current board
        persistence.saveCurrentBoardId(newBoard.id)

        // Start observing new board
        persistence.observeBoard(newBoard)
    }

    /// Create and switch to a new board
    func createNewBoard(title: String = "New Board") -> KanbanBoard {
        let newBoard = KanbanBoard.standard(title: title, projectRef: projectRef)
        try? persistence.saveBoard(newBoard)
        switchBoard(newBoard)
        return newBoard
    }

    /// Load all boards for current project
    func loadProjectBoards() -> [KanbanBoard] {
        persistence.loadBoards(forProject: projectRef)
    }

    /// Save board immediately (bypass debounce)
    func saveNow() throws {
        try persistence.saveBoard(board)
    }

    /// Reset all state (for new session)
    func reset() {
        bridge.reset()
    }

    /// Cleanup on deallocation
    deinit {
        persistence.stopObserving()
    }
}
