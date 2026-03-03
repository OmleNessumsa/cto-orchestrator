import Foundation

// MARK: - Kanban Column

/// Represents a column in the Kanban board that groups cards by workflow stage
struct KanbanColumn: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var cards: [KanbanCard]
    var limit: Int?        // Work-in-progress (WIP) limit
    var color: String?     // Optional hex color code
    var order: Int         // Display order (0-based)
    var isCollapsed: Bool  // Whether column is collapsed in UI

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        cards: [KanbanCard] = [],
        limit: Int? = nil,
        color: String? = nil,
        order: Int = 0,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.cards = cards
        self.limit = limit
        self.color = color
        self.order = order
        self.isCollapsed = isCollapsed
    }

    // MARK: - Computed Properties

    /// Number of cards in the column
    var cardCount: Int {
        cards.count
    }

    /// Whether the column is at or over its WIP limit
    var isAtLimit: Bool {
        guard let limit = limit else { return false }
        return cards.count >= limit
    }

    /// Whether the column is over its WIP limit
    var isOverLimit: Bool {
        guard let limit = limit else { return false }
        return cards.count > limit
    }

    /// Cards count relative to limit as a formatted string
    var limitDisplay: String {
        if let limit = limit {
            return "\(cards.count)/\(limit)"
        }
        return "\(cards.count)"
    }

    /// Whether the column is empty
    var isEmpty: Bool {
        cards.isEmpty
    }

    /// Total story points in the column
    var totalPoints: Int {
        cards.compactMap(\.estimatedPoints).reduce(0, +)
    }

    /// Cards sorted by priority (highest first)
    var cardsByPriority: [KanbanCard] {
        cards.sorted(by: KanbanCard.byPriority)
    }

    /// Cards sorted by due date (earliest first)
    var cardsByDueDate: [KanbanCard] {
        cards.sorted(by: KanbanCard.byDueDate)
    }

    /// Cards that are overdue
    var overdueCards: [KanbanCard] {
        cards.filter(\.isOverdue)
    }

    /// Cards that have no assignee
    var unassignedCards: [KanbanCard] {
        cards.filter { !$0.isAssigned }
    }

    // MARK: - Mutating Methods

    /// Add a card to the end of the column
    mutating func addCard(_ card: KanbanCard) {
        cards.append(card)
    }

    /// Add a card at a specific index
    mutating func insertCard(_ card: KanbanCard, at index: Int) {
        let safeIndex = min(max(0, index), cards.count)
        cards.insert(card, at: safeIndex)
    }

    /// Remove a card by ID
    @discardableResult
    mutating func removeCard(id: UUID) -> KanbanCard? {
        guard let index = cards.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return cards.remove(at: index)
    }

    /// Move a card within the column
    mutating func moveCard(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < cards.count,
              destinationIndex >= 0, destinationIndex <= cards.count else {
            return
        }
        let card = cards.remove(at: sourceIndex)
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        cards.insert(card, at: min(adjustedDestination, cards.count))
    }

    /// Update a card in place
    mutating func updateCard(_ card: KanbanCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        cards[index] = card
    }

    /// Find a card by ID
    func card(withId id: UUID) -> KanbanCard? {
        cards.first { $0.id == id }
    }

    /// Get index of a card
    func index(of cardId: UUID) -> Int? {
        cards.firstIndex { $0.id == cardId }
    }

    /// Sort cards in place
    mutating func sortCards(by comparator: (KanbanCard, KanbanCard) -> Bool) {
        cards.sort(by: comparator)
    }

    /// Clear all cards from the column
    mutating func clearCards() {
        cards.removeAll()
    }
}

// MARK: - Column Presets

extension KanbanColumn {
    /// Default backlog column
    static func backlog(order: Int = 0) -> KanbanColumn {
        KanbanColumn(
            title: "Backlog",
            limit: nil,
            color: "#607D8B",
            order: order
        )
    }

    /// Default in-progress column with WIP limit
    static func inProgress(order: Int = 1, limit: Int = 3) -> KanbanColumn {
        KanbanColumn(
            title: "In Progress",
            limit: limit,
            color: "#2196F3",
            order: order
        )
    }

    /// Default review column with WIP limit
    static func review(order: Int = 2, limit: Int = 2) -> KanbanColumn {
        KanbanColumn(
            title: "Review",
            limit: limit,
            color: "#9C27B0",
            order: order
        )
    }

    /// Default done column
    static func done(order: Int = 3) -> KanbanColumn {
        KanbanColumn(
            title: "Done",
            limit: nil,
            color: "#4CAF50",
            order: order
        )
    }

    /// Default blocked column (optional)
    static func blocked(order: Int = 4) -> KanbanColumn {
        KanbanColumn(
            title: "Blocked",
            limit: nil,
            color: "#F44336",
            order: order
        )
    }

    /// Standard set of Kanban columns
    static var standardColumns: [KanbanColumn] {
        [
            .backlog(order: 0),
            .inProgress(order: 1),
            .review(order: 2),
            .done(order: 3)
        ]
    }

    /// Extended set including blocked column
    static var extendedColumns: [KanbanColumn] {
        [
            .backlog(order: 0),
            .inProgress(order: 1),
            .review(order: 2),
            .blocked(order: 3),
            .done(order: 4)
        ]
    }
}

// MARK: - Column Sorting

extension KanbanColumn {
    /// Sort columns by their order property
    static func byOrder(_ lhs: KanbanColumn, _ rhs: KanbanColumn) -> Bool {
        lhs.order < rhs.order
    }
}
