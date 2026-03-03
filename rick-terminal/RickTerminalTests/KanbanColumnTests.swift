import XCTest
@testable import RickTerminal

/// Unit tests for KanbanColumn model
class KanbanColumnTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // Given/When
        let column = KanbanColumn(title: "Test Column")

        // Then
        XCTAssertEqual(column.title, "Test Column")
        XCTAssertTrue(column.cards.isEmpty)
        XCTAssertNil(column.limit)
        XCTAssertNil(column.color)
        XCTAssertEqual(column.order, 0)
        XCTAssertFalse(column.isCollapsed)
    }

    func testFullInitialization() {
        // Given
        let cards = [
            KanbanCard(title: "Card 1"),
            KanbanCard(title: "Card 2")
        ]

        // When
        let column = KanbanColumn(
            title: "In Progress",
            cards: cards,
            limit: 3,
            color: "#2196F3",
            order: 1,
            isCollapsed: true
        )

        // Then
        XCTAssertEqual(column.title, "In Progress")
        XCTAssertEqual(column.cards.count, 2)
        XCTAssertEqual(column.limit, 3)
        XCTAssertEqual(column.color, "#2196F3")
        XCTAssertEqual(column.order, 1)
        XCTAssertTrue(column.isCollapsed)
    }

    // MARK: - Encoding/Decoding Tests

    func testEncodeDecode() throws {
        // Given
        let cards = [
            KanbanCard(title: "Card 1"),
            KanbanCard(title: "Card 2")
        ]
        let original = KanbanColumn(
            title: "Review",
            cards: cards,
            limit: 2,
            color: "#9C27B0",
            order: 2
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KanbanColumn.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.cards.count, original.cards.count)
        XCTAssertEqual(decoded.limit, original.limit)
        XCTAssertEqual(decoded.color, original.color)
        XCTAssertEqual(decoded.order, original.order)
    }

    // MARK: - Computed Properties Tests

    func testCardCount() {
        // Given
        var column = KanbanColumn(title: "Test")
        XCTAssertEqual(column.cardCount, 0)

        // When
        column.addCard(KanbanCard(title: "Card 1"))
        column.addCard(KanbanCard(title: "Card 2"))

        // Then
        XCTAssertEqual(column.cardCount, 2)
    }

    func testIsAtLimit() {
        // Given
        var column = KanbanColumn(title: "Test", limit: 2)

        // When/Then
        XCTAssertFalse(column.isAtLimit) // 0 < 2
        column.addCard(KanbanCard(title: "Card 1"))
        XCTAssertFalse(column.isAtLimit) // 1 < 2
        column.addCard(KanbanCard(title: "Card 2"))
        XCTAssertTrue(column.isAtLimit) // 2 >= 2
        column.addCard(KanbanCard(title: "Card 3"))
        XCTAssertTrue(column.isAtLimit) // 3 >= 2
    }

    func testIsOverLimit() {
        // Given
        var column = KanbanColumn(title: "Test", limit: 2)

        // When/Then
        XCTAssertFalse(column.isOverLimit) // 0 <= 2
        column.addCard(KanbanCard(title: "Card 1"))
        XCTAssertFalse(column.isOverLimit) // 1 <= 2
        column.addCard(KanbanCard(title: "Card 2"))
        XCTAssertFalse(column.isOverLimit) // 2 == 2
        column.addCard(KanbanCard(title: "Card 3"))
        XCTAssertTrue(column.isOverLimit) // 3 > 2
    }

    func testLimitWithNoLimit() {
        // Given
        var column = KanbanColumn(title: "Test", limit: nil)
        column.addCard(KanbanCard(title: "Card 1"))
        column.addCard(KanbanCard(title: "Card 2"))

        // When/Then
        XCTAssertFalse(column.isAtLimit)
        XCTAssertFalse(column.isOverLimit)
    }

    func testLimitDisplay() {
        // Given
        var noLimit = KanbanColumn(title: "No Limit")
        var withLimit = KanbanColumn(title: "With Limit", limit: 5)

        // When
        noLimit.addCard(KanbanCard(title: "Card 1"))
        withLimit.addCard(KanbanCard(title: "Card 1"))
        withLimit.addCard(KanbanCard(title: "Card 2"))

        // Then
        XCTAssertEqual(noLimit.limitDisplay, "1")
        XCTAssertEqual(withLimit.limitDisplay, "2/5")
    }

    func testIsEmpty() {
        // Given
        var column = KanbanColumn(title: "Test")

        // When/Then
        XCTAssertTrue(column.isEmpty)
        column.addCard(KanbanCard(title: "Card 1"))
        XCTAssertFalse(column.isEmpty)
    }

    func testTotalPoints() {
        // Given
        var column = KanbanColumn(title: "Test")

        // When
        column.addCard(KanbanCard(title: "Card 1", estimatedPoints: 3))
        column.addCard(KanbanCard(title: "Card 2", estimatedPoints: 5))
        column.addCard(KanbanCard(title: "Card 3")) // No points

        // Then
        XCTAssertEqual(column.totalPoints, 8)
    }

    func testCardsByPriority() {
        // Given
        var column = KanbanColumn(title: "Test")
        column.addCard(KanbanCard(title: "Low", priority: .low))
        column.addCard(KanbanCard(title: "Critical", priority: .critical))
        column.addCard(KanbanCard(title: "Medium", priority: .medium))

        // When
        let sorted = column.cardsByPriority

        // Then (highest first)
        XCTAssertEqual(sorted[0].priority, .critical)
        XCTAssertEqual(sorted[1].priority, .medium)
        XCTAssertEqual(sorted[2].priority, .low)
    }

    func testCardsByDueDate() {
        // Given
        var column = KanbanColumn(title: "Test")
        let noDueDate = KanbanCard(title: "No Due Date")
        let soon = KanbanCard(title: "Soon", dueDate: Date().addingTimeInterval(86400))
        let later = KanbanCard(title: "Later", dueDate: Date().addingTimeInterval(2 * 86400))

        column.addCard(noDueDate)
        column.addCard(later)
        column.addCard(soon)

        // When
        let sorted = column.cardsByDueDate

        // Then (earliest first, nil last)
        XCTAssertEqual(sorted[0].title, "Soon")
        XCTAssertEqual(sorted[1].title, "Later")
        XCTAssertEqual(sorted[2].title, "No Due Date")
    }

    func testOverdueCards() {
        // Given
        var column = KanbanColumn(title: "Test")
        let overdue = KanbanCard(title: "Overdue", dueDate: Date().addingTimeInterval(-86400))
        let notDue = KanbanCard(title: "Not Due", dueDate: Date().addingTimeInterval(86400))
        let noDueDate = KanbanCard(title: "No Due Date")

        column.addCard(overdue)
        column.addCard(notDue)
        column.addCard(noDueDate)

        // When
        let overdueCards = column.overdueCards

        // Then
        XCTAssertEqual(overdueCards.count, 1)
        XCTAssertEqual(overdueCards[0].title, "Overdue")
    }

    func testUnassignedCards() {
        // Given
        var column = KanbanColumn(title: "Test")
        column.addCard(KanbanCard(title: "Assigned", assignee: "Rick"))
        column.addCard(KanbanCard(title: "Unassigned 1"))
        column.addCard(KanbanCard(title: "Unassigned 2"))

        // When
        let unassigned = column.unassignedCards

        // Then
        XCTAssertEqual(unassigned.count, 2)
    }

    // MARK: - Mutating Methods Tests

    func testAddCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card = KanbanCard(title: "New Card")

        // When
        column.addCard(card)

        // Then
        XCTAssertEqual(column.cards.count, 1)
        XCTAssertEqual(column.cards[0].id, card.id)
    }

    func testInsertCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")
        let card3 = KanbanCard(title: "Card 3")

        column.addCard(card1)
        column.addCard(card3)

        // When
        column.insertCard(card2, at: 1)

        // Then
        XCTAssertEqual(column.cards.count, 3)
        XCTAssertEqual(column.cards[0].id, card1.id)
        XCTAssertEqual(column.cards[1].id, card2.id)
        XCTAssertEqual(column.cards[2].id, card3.id)
    }

    func testInsertCardAtBounds() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")
        let card3 = KanbanCard(title: "Card 3")

        column.addCard(card2)

        // When - Insert at negative index (should insert at 0)
        column.insertCard(card1, at: -1)
        // When - Insert beyond bounds (should insert at end)
        column.insertCard(card3, at: 100)

        // Then
        XCTAssertEqual(column.cards.count, 3)
        XCTAssertEqual(column.cards[0].id, card1.id)
        XCTAssertEqual(column.cards[2].id, card3.id)
    }

    func testRemoveCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")

        column.addCard(card1)
        column.addCard(card2)

        // When
        let removed = column.removeCard(id: card1.id)

        // Then
        XCTAssertEqual(removed?.id, card1.id)
        XCTAssertEqual(column.cards.count, 1)
        XCTAssertEqual(column.cards[0].id, card2.id)
    }

    func testRemoveNonExistentCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        column.addCard(KanbanCard(title: "Card 1"))

        // When
        let removed = column.removeCard(id: UUID())

        // Then
        XCTAssertNil(removed)
        XCTAssertEqual(column.cards.count, 1)
    }

    func testMoveCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")
        let card3 = KanbanCard(title: "Card 3")

        column.addCard(card1)
        column.addCard(card2)
        column.addCard(card3)

        // When - Move card from index 0 to index 2
        column.moveCard(from: 0, to: 2)

        // Then
        XCTAssertEqual(column.cards[0].id, card2.id)
        XCTAssertEqual(column.cards[1].id, card1.id)
        XCTAssertEqual(column.cards[2].id, card3.id)
    }

    func testMoveCardBackward() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")
        let card3 = KanbanCard(title: "Card 3")

        column.addCard(card1)
        column.addCard(card2)
        column.addCard(card3)

        // When - Move card from index 2 to index 0
        column.moveCard(from: 2, to: 0)

        // Then
        XCTAssertEqual(column.cards[0].id, card3.id)
        XCTAssertEqual(column.cards[1].id, card1.id)
        XCTAssertEqual(column.cards[2].id, card2.id)
    }

    func testMoveCardInvalidIndices() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")

        column.addCard(card1)
        column.addCard(card2)

        // When - Try invalid moves
        column.moveCard(from: 0, to: 0) // Same index
        column.moveCard(from: -1, to: 1) // Negative source
        column.moveCard(from: 0, to: 100) // Out of bounds destination

        // Then - Cards should remain unchanged
        XCTAssertEqual(column.cards.count, 2)
        XCTAssertEqual(column.cards[0].id, card1.id)
        XCTAssertEqual(column.cards[1].id, card2.id)
    }

    func testUpdateCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card = KanbanCard(title: "Original")
        column.addCard(card)

        // When
        let updated = card.withStatus(.done)
        column.updateCard(updated)

        // Then
        XCTAssertEqual(column.cards[0].status, .done)
        XCTAssertEqual(column.cards[0].id, card.id)
    }

    func testUpdateNonExistentCard() {
        // Given
        var column = KanbanColumn(title: "Test")
        column.addCard(KanbanCard(title: "Card 1"))
        let nonExistent = KanbanCard(title: "Non-existent")

        let initialCount = column.cards.count

        // When
        column.updateCard(nonExistent)

        // Then - Should not change anything
        XCTAssertEqual(column.cards.count, initialCount)
    }

    // MARK: - Lookup Methods Tests

    func testCardWithId() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")

        column.addCard(card1)
        column.addCard(card2)

        // When
        let found = column.card(withId: card2.id)
        let notFound = column.card(withId: UUID())

        // Then
        XCTAssertEqual(found?.id, card2.id)
        XCTAssertNil(notFound)
    }

    func testIndexOf() {
        // Given
        var column = KanbanColumn(title: "Test")
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")

        column.addCard(card1)
        column.addCard(card2)

        // When
        let index1 = column.index(of: card1.id)
        let index2 = column.index(of: card2.id)
        let notFound = column.index(of: UUID())

        // Then
        XCTAssertEqual(index1, 0)
        XCTAssertEqual(index2, 1)
        XCTAssertNil(notFound)
    }

    func testSortCards() {
        // Given
        var column = KanbanColumn(title: "Test")
        column.addCard(KanbanCard(title: "Low", priority: .low))
        column.addCard(KanbanCard(title: "High", priority: .high))
        column.addCard(KanbanCard(title: "Medium", priority: .medium))

        // When
        column.sortCards(by: KanbanCard.byPriority)

        // Then
        XCTAssertEqual(column.cards[0].priority, .high)
        XCTAssertEqual(column.cards[1].priority, .medium)
        XCTAssertEqual(column.cards[2].priority, .low)
    }

    // MARK: - Preset Columns Tests

    func testBacklogPreset() {
        let column = KanbanColumn.backlog(order: 0)
        XCTAssertEqual(column.title, "Backlog")
        XCTAssertNil(column.limit)
        XCTAssertEqual(column.color, "#607D8B")
        XCTAssertEqual(column.order, 0)
    }

    func testInProgressPreset() {
        let column = KanbanColumn.inProgress(order: 1, limit: 5)
        XCTAssertEqual(column.title, "In Progress")
        XCTAssertEqual(column.limit, 5)
        XCTAssertEqual(column.color, "#2196F3")
        XCTAssertEqual(column.order, 1)
    }

    func testReviewPreset() {
        let column = KanbanColumn.review(order: 2, limit: 3)
        XCTAssertEqual(column.title, "Review")
        XCTAssertEqual(column.limit, 3)
        XCTAssertEqual(column.color, "#9C27B0")
        XCTAssertEqual(column.order, 2)
    }

    func testDonePreset() {
        let column = KanbanColumn.done(order: 3)
        XCTAssertEqual(column.title, "Done")
        XCTAssertNil(column.limit)
        XCTAssertEqual(column.color, "#4CAF50")
        XCTAssertEqual(column.order, 3)
    }

    func testBlockedPreset() {
        let column = KanbanColumn.blocked(order: 4)
        XCTAssertEqual(column.title, "Blocked")
        XCTAssertNil(column.limit)
        XCTAssertEqual(column.color, "#F44336")
        XCTAssertEqual(column.order, 4)
    }

    func testStandardColumns() {
        let columns = KanbanColumn.standardColumns
        XCTAssertEqual(columns.count, 4)
        XCTAssertEqual(columns[0].title, "Backlog")
        XCTAssertEqual(columns[1].title, "In Progress")
        XCTAssertEqual(columns[2].title, "Review")
        XCTAssertEqual(columns[3].title, "Done")
    }

    func testExtendedColumns() {
        let columns = KanbanColumn.extendedColumns
        XCTAssertEqual(columns.count, 5)
        XCTAssertEqual(columns[0].title, "Backlog")
        XCTAssertEqual(columns[1].title, "In Progress")
        XCTAssertEqual(columns[2].title, "Review")
        XCTAssertEqual(columns[3].title, "Blocked")
        XCTAssertEqual(columns[4].title, "Done")
    }

    // MARK: - Sorting Tests

    func testColumnSortByOrder() {
        // Given
        let column1 = KanbanColumn(title: "Third", order: 2)
        let column2 = KanbanColumn(title: "First", order: 0)
        let column3 = KanbanColumn(title: "Second", order: 1)

        var columns = [column1, column2, column3]

        // When
        columns.sort(by: KanbanColumn.byOrder)

        // Then
        XCTAssertEqual(columns[0].title, "First")
        XCTAssertEqual(columns[1].title, "Second")
        XCTAssertEqual(columns[2].title, "Third")
    }
}
