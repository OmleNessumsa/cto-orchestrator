import Foundation
import Combine

// MARK: - Codable Board (Persistence)

/// Codable representation of KanbanBoard for JSON persistence
struct CodableBoard: Codable {
    let id: UUID
    let title: String
    let columns: [KanbanColumn]
    let createdAt: Date
    let updatedAt: Date
    let projectRef: String?

    init(from board: KanbanBoard) {
        self.id = board.id
        self.title = board.title
        self.columns = board.columns
        self.createdAt = board.createdAt
        self.updatedAt = board.updatedAt
        self.projectRef = board.projectRef
    }
}

// MARK: - Kanban Board

/// Observable Kanban board with thread-safe updates
final class KanbanBoard: Identifiable, ObservableObject {
    let id: UUID
    var title: String
    @Published private(set) var columns: [KanbanColumn]
    let createdAt: Date
    private(set) var updatedAt: Date
    var projectRef: String?  // Reference to project (e.g., "rick-terminal")

    /// Serial queue for thread-safe mutations
    private let updateQueue: DispatchQueue

    /// Publisher for individual card events
    private let cardEventSubject = PassthroughSubject<CardEvent, Never>()

    /// Card events stream for external subscribers
    var cardEvents: AnyPublisher<CardEvent, Never> {
        cardEventSubject.eraseToAnyPublisher()
    }

    // MARK: - Card Events

    enum CardEvent {
        case added(card: KanbanCard, columnId: UUID)
        case removed(cardId: UUID, columnId: UUID)
        case moved(cardId: UUID, fromColumnId: UUID, toColumnId: UUID)
        case updated(card: KanbanCard, columnId: UUID)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String = "Kanban Board",
        columns: [KanbanColumn] = KanbanColumn.standardColumns,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projectRef: String? = nil
    ) {
        self.id = id
        self.title = title
        self.columns = columns.sorted(by: KanbanColumn.byOrder)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectRef = projectRef
        self.updateQueue = DispatchQueue(
            label: "com.rick.terminal.kanban.board.\(id.uuidString)",
            qos: .userInitiated
        )
    }

    /// Create board from codable representation
    convenience init(from codable: CodableBoard) {
        self.init(
            id: codable.id,
            title: codable.title,
            columns: codable.columns,
            createdAt: codable.createdAt,
            updatedAt: codable.updatedAt,
            projectRef: codable.projectRef
        )
    }

    /// Convert to codable for persistence
    func toCodable() -> CodableBoard {
        CodableBoard(from: self)
    }

    // MARK: - Computed Properties

    /// Total number of cards across all columns
    var totalCards: Int {
        columns.reduce(0) { $0 + $1.cardCount }
    }

    /// All cards grouped by status
    var cardsByStatus: [CardStatus: [KanbanCard]] {
        var result: [CardStatus: [KanbanCard]] = [:]
        for column in columns {
            for card in column.cards {
                result[card.status, default: []].append(card)
            }
        }
        return result
    }

    /// All cards flattened
    var allCards: [KanbanCard] {
        columns.flatMap(\.cards)
    }

    /// Total story points on the board
    var totalPoints: Int {
        columns.reduce(0) { $0 + $1.totalPoints }
    }

    /// All overdue cards
    var overdueCards: [KanbanCard] {
        columns.flatMap(\.overdueCards)
    }

    /// All unassigned cards
    var unassignedCards: [KanbanCard] {
        columns.flatMap(\.unassignedCards)
    }

    /// Columns that are at or over their WIP limit
    var columnsAtLimit: [KanbanColumn] {
        columns.filter(\.isAtLimit)
    }

    // MARK: - Thread-Safe Mutations

    /// Clear all cards from all columns
    /// Must be called from main thread, completes synchronously
    func clearAllCards() {
        assert(Thread.isMainThread, "clearAllCards must be called from main thread")

        var updatedColumns = columns
        for i in updatedColumns.indices {
            updatedColumns[i].clearCards()
        }
        columns = updatedColumns
        updatedAt = Date()
    }

    /// Add multiple cards at once (batch operation for efficiency)
    /// Must be called from main thread
    func addCards(_ cardsWithColumns: [(card: KanbanCard, columnId: UUID)]) {
        assert(Thread.isMainThread, "addCards must be called from main thread")

        var updatedColumns = columns

        for (card, columnId) in cardsWithColumns {
            guard let columnIndex = updatedColumns.firstIndex(where: { $0.id == columnId }) else {
                continue
            }
            updatedColumns[columnIndex].addCard(card)
        }

        columns = updatedColumns
        updatedAt = Date()
    }

    /// Add a card to a column
    func addCard(_ card: KanbanCard, to columnId: UUID) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            guard let columnIndex = self.columns.firstIndex(where: { $0.id == columnId }) else {
                return
            }

            var updatedColumns = self.columns
            updatedColumns[columnIndex].addCard(card)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
                self.cardEventSubject.send(.added(card: card, columnId: columnId))
            }
        }
    }

    /// Add a card at a specific index in a column
    func insertCard(_ card: KanbanCard, in columnId: UUID, at index: Int) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            guard let columnIndex = self.columns.firstIndex(where: { $0.id == columnId }) else {
                return
            }

            var updatedColumns = self.columns
            updatedColumns[columnIndex].insertCard(card, at: index)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
                self.cardEventSubject.send(.added(card: card, columnId: columnId))
            }
        }
    }

    /// Remove a card from a column
    func removeCard(id cardId: UUID, from columnId: UUID) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            guard let columnIndex = self.columns.firstIndex(where: { $0.id == columnId }) else {
                return
            }

            var updatedColumns = self.columns
            updatedColumns[columnIndex].removeCard(id: cardId)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
                self.cardEventSubject.send(.removed(cardId: cardId, columnId: columnId))
            }
        }
    }

    /// Move a card between columns
    func moveCard(_ cardId: UUID, from sourceColumnId: UUID, to targetColumnId: UUID, at index: Int = -1) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            guard let sourceIndex = self.columns.firstIndex(where: { $0.id == sourceColumnId }),
                  let targetIndex = self.columns.firstIndex(where: { $0.id == targetColumnId }) else {
                return
            }

            var updatedColumns = self.columns

            // Remove from source
            guard let card = updatedColumns[sourceIndex].removeCard(id: cardId) else {
                return
            }

            // Insert into target
            let targetPosition = index < 0 ? updatedColumns[targetIndex].cardCount : index
            updatedColumns[targetIndex].insertCard(card, at: targetPosition)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
                self.cardEventSubject.send(.moved(
                    cardId: cardId,
                    fromColumnId: sourceColumnId,
                    toColumnId: targetColumnId
                ))
            }
        }
    }

    /// Update a card in place
    func updateCard(_ card: KanbanCard, in columnId: UUID) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            guard let columnIndex = self.columns.firstIndex(where: { $0.id == columnId }) else {
                return
            }

            var updatedColumns = self.columns
            updatedColumns[columnIndex].updateCard(card)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
                self.cardEventSubject.send(.updated(card: card, columnId: columnId))
            }
        }
    }

    /// Reorder a card within the same column
    func reorderCard(in columnId: UUID, from sourceIndex: Int, to destinationIndex: Int) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            guard let columnIndex = self.columns.firstIndex(where: { $0.id == columnId }) else {
                return
            }

            var updatedColumns = self.columns
            updatedColumns[columnIndex].moveCard(from: sourceIndex, to: destinationIndex)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
            }
        }
    }

    /// Add a new column
    func addColumn(_ column: KanbanColumn) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            var updatedColumns = self.columns
            updatedColumns.append(column)
            updatedColumns.sort(by: KanbanColumn.byOrder)
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
            }
        }
    }

    /// Remove a column
    func removeColumn(id columnId: UUID) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            var updatedColumns = self.columns
            updatedColumns.removeAll { $0.id == columnId }
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
            }
        }
    }

    /// Update column properties (not cards)
    func updateColumn(id columnId: UUID, title: String? = nil, limit: Int?? = nil, color: String?? = nil) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            guard let columnIndex = self.columns.firstIndex(where: { $0.id == columnId }) else {
                return
            }

            var updatedColumns = self.columns
            if let title = title {
                updatedColumns[columnIndex].title = title
            }
            if let limit = limit {
                updatedColumns[columnIndex].limit = limit
            }
            if let color = color {
                updatedColumns[columnIndex].color = color
            }
            let updatedAt = Date()

            DispatchQueue.main.async {
                self.columns = updatedColumns
                self.updatedAt = updatedAt
            }
        }
    }

    // MARK: - Lookup Methods

    /// Find a card by ID across all columns
    func findCard(id cardId: UUID) -> (card: KanbanCard, columnId: UUID)? {
        for column in columns {
            if let card = column.card(withId: cardId) {
                return (card, column.id)
            }
        }
        return nil
    }

    /// Find a column by ID
    func column(withId columnId: UUID) -> KanbanColumn? {
        columns.first { $0.id == columnId }
    }

    /// Find cards with a specific label
    func cards(withLabel label: CardLabel) -> [KanbanCard] {
        allCards.filter { $0.labels.contains(label) }
    }

    /// Find cards assigned to an agent
    func cards(assignedTo agent: String) -> [KanbanCard] {
        allCards.filter { $0.assignee == agent }
    }

    /// Find cards with a specific ticket reference
    func card(withTicketRef ticketRef: String) -> KanbanCard? {
        allCards.first { $0.ticketRef == ticketRef }
    }
}

// MARK: - JSON Persistence

extension KanbanBoard {
    /// Save board to JSON file
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(toCodable())
        try data.write(to: url)
    }

    /// Load board from JSON file
    static func load(from url: URL) throws -> KanbanBoard {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let codable = try decoder.decode(CodableBoard.self, from: data)
        return KanbanBoard(from: codable)
    }

    /// Convert board to JSON data
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(toCodable())
    }

    /// Create board from JSON data
    static func fromJSONData(_ data: Data) throws -> KanbanBoard {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let codable = try decoder.decode(CodableBoard.self, from: data)
        return KanbanBoard(from: codable)
    }
}

// MARK: - Factory Methods

extension KanbanBoard {
    /// Create a new empty board with standard columns
    static func standard(title: String = "Kanban Board", projectRef: String? = nil) -> KanbanBoard {
        KanbanBoard(
            title: title,
            columns: KanbanColumn.standardColumns,
            projectRef: projectRef
        )
    }

    /// Create a new board with extended columns (including blocked)
    static func extended(title: String = "Kanban Board", projectRef: String? = nil) -> KanbanBoard {
        KanbanBoard(
            title: title,
            columns: KanbanColumn.extendedColumns,
            projectRef: projectRef
        )
    }

    /// Create a sprint board with time-boxed columns
    static func sprint(title: String = "Sprint Board", projectRef: String? = nil) -> KanbanBoard {
        let columns: [KanbanColumn] = [
            KanbanColumn(title: "Sprint Backlog", limit: nil, color: "#607D8B", order: 0),
            KanbanColumn(title: "In Progress", limit: 5, color: "#2196F3", order: 1),
            KanbanColumn(title: "Code Review", limit: 3, color: "#9C27B0", order: 2),
            KanbanColumn(title: "Testing", limit: 2, color: "#FF9800", order: 3),
            KanbanColumn(title: "Done", limit: nil, color: "#4CAF50", order: 4)
        ]
        return KanbanBoard(title: title, columns: columns, projectRef: projectRef)
    }
}
