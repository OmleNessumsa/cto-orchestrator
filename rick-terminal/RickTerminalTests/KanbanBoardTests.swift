import XCTest
import Combine
@testable import RickTerminal

/// Unit tests for KanbanBoard model
class KanbanBoardTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // Given/When
        let board = KanbanBoard()

        // Then
        XCTAssertEqual(board.title, "Kanban Board")
        XCTAssertEqual(board.columns.count, 4) // Standard columns
        XCTAssertNil(board.projectRef)
    }

    func testFullInitialization() {
        // Given
        let columns = KanbanColumn.standardColumns
        let id = UUID()

        // When
        let board = KanbanBoard(
            id: id,
            title: "Custom Board",
            columns: columns,
            projectRef: "rick-terminal"
        )

        // Then
        XCTAssertEqual(board.id, id)
        XCTAssertEqual(board.title, "Custom Board")
        XCTAssertEqual(board.columns.count, 4)
        XCTAssertEqual(board.projectRef, "rick-terminal")
    }

    func testColumnsSortedByOrder() {
        // Given - Add columns in random order
        let columns = [
            KanbanColumn(title: "Third", order: 2),
            KanbanColumn(title: "First", order: 0),
            KanbanColumn(title: "Second", order: 1)
        ]

        // When
        let board = KanbanBoard(columns: columns)

        // Then - Should be sorted by order
        XCTAssertEqual(board.columns[0].title, "First")
        XCTAssertEqual(board.columns[1].title, "Second")
        XCTAssertEqual(board.columns[2].title, "Third")
    }

    // MARK: - Codable Tests

    func testToCodable() {
        // Given
        let board = KanbanBoard(title: "Test Board", projectRef: "test-project")

        // When
        let codable = board.toCodable()

        // Then
        XCTAssertEqual(codable.id, board.id)
        XCTAssertEqual(codable.title, board.title)
        XCTAssertEqual(codable.columns.count, board.columns.count)
        XCTAssertEqual(codable.projectRef, board.projectRef)
    }

    func testFromCodable() {
        // Given
        let original = KanbanBoard(title: "Original", projectRef: "test")
        let codable = original.toCodable()

        // When
        let restored = KanbanBoard(from: codable)

        // Then
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.title, original.title)
        XCTAssertEqual(restored.columns.count, original.columns.count)
        XCTAssertEqual(restored.projectRef, original.projectRef)
    }

    func testToJSONData() throws {
        // Given
        let board = KanbanBoard(title: "Test Board")

        // When
        let data = try board.toJSONData()

        // Then
        XCTAssertGreaterThan(data.count, 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["title"] as? String, "Test Board")
    }

    func testFromJSONData() throws {
        // Given
        let original = KanbanBoard(title: "Original Board", projectRef: "test")
        let data = try original.toJSONData()

        // When
        let restored = try KanbanBoard.fromJSONData(data)

        // Then
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.title, original.title)
        XCTAssertEqual(restored.projectRef, original.projectRef)
    }

    func testSaveAndLoadFromFile() throws {
        // Given
        let board = KanbanBoard(title: "Test Board", projectRef: "test-project")
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-board.json")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: fileURL)

        // When
        try board.save(to: fileURL)
        let loaded = try KanbanBoard.load(from: fileURL)

        // Then
        XCTAssertEqual(loaded.id, board.id)
        XCTAssertEqual(loaded.title, board.title)
        XCTAssertEqual(loaded.projectRef, board.projectRef)

        // Clean up
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Computed Properties Tests

    func testTotalCards() {
        // Given
        let board = KanbanBoard.standard()
        let column1Id = board.columns[0].id
        let column2Id = board.columns[1].id

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        board.addCard(KanbanCard(title: "Card 1"), to: column1Id)
        board.addCard(KanbanCard(title: "Card 2"), to: column1Id)
        board.addCard(KanbanCard(title: "Card 3"), to: column2Id)

        // Wait for async operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.totalCards, 3)
    }

    func testCardsByStatus() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        board.addCard(KanbanCard(title: "Card 1", status: .backlog), to: columnId)
        board.addCard(KanbanCard(title: "Card 2", status: .backlog), to: columnId)
        board.addCard(KanbanCard(title: "Card 3", status: .inProgress), to: columnId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        let byStatus = board.cardsByStatus
        XCTAssertEqual(byStatus[.backlog]?.count, 2)
        XCTAssertEqual(byStatus[.inProgress]?.count, 1)
    }

    func testAllCards() {
        // Given
        let board = KanbanBoard.standard()
        let column1Id = board.columns[0].id
        let column2Id = board.columns[1].id

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        board.addCard(KanbanCard(title: "Card 1"), to: column1Id)
        board.addCard(KanbanCard(title: "Card 2"), to: column2Id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.allCards.count, 2)
    }

    func testTotalPoints() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        board.addCard(KanbanCard(title: "Card 1", estimatedPoints: 3), to: columnId)
        board.addCard(KanbanCard(title: "Card 2", estimatedPoints: 5), to: columnId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.totalPoints, 8)
    }

    func testOverdueCards() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let past = Date().addingTimeInterval(-86400)

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        board.addCard(KanbanCard(title: "Overdue", dueDate: past), to: columnId)
        board.addCard(KanbanCard(title: "Not Due", dueDate: Date().addingTimeInterval(86400)), to: columnId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.overdueCards.count, 1)
        XCTAssertEqual(board.overdueCards[0].title, "Overdue")
    }

    func testUnassignedCards() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        board.addCard(KanbanCard(title: "Assigned", assignee: "Rick"), to: columnId)
        board.addCard(KanbanCard(title: "Unassigned"), to: columnId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.unassignedCards.count, 1)
        XCTAssertEqual(board.unassignedCards[0].title, "Unassigned")
    }

    func testColumnsAtLimit() {
        // Given
        let board = KanbanBoard.standard()
        let inProgressColumn = board.columns.first { $0.title == "In Progress" }!

        // When
        let expectation = XCTestExpectation(description: "Cards added")
        // Add cards up to the limit (3)
        board.addCard(KanbanCard(title: "Card 1"), to: inProgressColumn.id)
        board.addCard(KanbanCard(title: "Card 2"), to: inProgressColumn.id)
        board.addCard(KanbanCard(title: "Card 3"), to: inProgressColumn.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.columnsAtLimit.count, 1)
        XCTAssertEqual(board.columnsAtLimit[0].title, "In Progress")
    }

    // MARK: - Card Operations Tests

    func testAddCard() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card = KanbanCard(title: "Test Card")

        let expectation = XCTestExpectation(description: "Card added")
        var eventReceived = false

        board.cardEvents.sink { event in
            if case .added(let addedCard, let addedColumnId) = event {
                XCTAssertEqual(addedCard.id, card.id)
                XCTAssertEqual(addedColumnId, columnId)
                eventReceived = true
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        // When
        board.addCard(card, to: columnId)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(eventReceived)
        XCTAssertEqual(board.totalCards, 1)
    }

    func testInsertCardAtIndex() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")
        let card3 = KanbanCard(title: "Card 3")

        let expectation = XCTestExpectation(description: "Cards inserted")
        expectation.expectedFulfillmentCount = 3

        board.cardEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // When
        board.addCard(card1, to: columnId)
        board.addCard(card3, to: columnId)
        board.insertCard(card2, in: columnId, at: 1)

        // Then
        wait(for: [expectation], timeout: 1.0)

        let column = board.column(withId: columnId)!
        XCTAssertEqual(column.cards.count, 3)
        XCTAssertEqual(column.cards[1].id, card2.id)
    }

    func testRemoveCard() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card = KanbanCard(title: "Test Card")

        let addExpectation = XCTestExpectation(description: "Card added")
        let removeExpectation = XCTestExpectation(description: "Card removed")

        var eventCount = 0
        board.cardEvents.sink { event in
            eventCount += 1
            if eventCount == 1, case .added = event {
                addExpectation.fulfill()
            } else if eventCount == 2, case .removed(let cardId, let colId) = event {
                XCTAssertEqual(cardId, card.id)
                XCTAssertEqual(colId, columnId)
                removeExpectation.fulfill()
            }
        }.store(in: &cancellables)

        // When
        board.addCard(card, to: columnId)
        wait(for: [addExpectation], timeout: 1.0)

        board.removeCard(id: card.id, from: columnId)

        // Then
        wait(for: [removeExpectation], timeout: 1.0)
        XCTAssertEqual(board.totalCards, 0)
    }

    func testMoveCard() {
        // Given
        let board = KanbanBoard.standard()
        let sourceColumnId = board.columns[0].id
        let targetColumnId = board.columns[1].id
        let card = KanbanCard(title: "Test Card")

        let addExpectation = XCTestExpectation(description: "Card added")
        let moveExpectation = XCTestExpectation(description: "Card moved")

        var eventCount = 0
        board.cardEvents.sink { event in
            eventCount += 1
            if eventCount == 1, case .added = event {
                addExpectation.fulfill()
            } else if eventCount == 2, case .moved(let cardId, let fromId, let toId) = event {
                XCTAssertEqual(cardId, card.id)
                XCTAssertEqual(fromId, sourceColumnId)
                XCTAssertEqual(toId, targetColumnId)
                moveExpectation.fulfill()
            }
        }.store(in: &cancellables)

        // When
        board.addCard(card, to: sourceColumnId)
        wait(for: [addExpectation], timeout: 1.0)

        board.moveCard(card.id, from: sourceColumnId, to: targetColumnId)

        // Then
        wait(for: [moveExpectation], timeout: 1.0)

        let sourceColumn = board.column(withId: sourceColumnId)!
        let targetColumn = board.column(withId: targetColumnId)!
        XCTAssertEqual(sourceColumn.cards.count, 0)
        XCTAssertEqual(targetColumn.cards.count, 1)
        XCTAssertEqual(targetColumn.cards[0].id, card.id)
    }

    func testUpdateCard() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card = KanbanCard(title: "Original")

        let addExpectation = XCTestExpectation(description: "Card added")
        let updateExpectation = XCTestExpectation(description: "Card updated")

        var eventCount = 0
        board.cardEvents.sink { event in
            eventCount += 1
            if eventCount == 1, case .added = event {
                addExpectation.fulfill()
            } else if eventCount == 2, case .updated(let updatedCard, _) = event {
                XCTAssertEqual(updatedCard.title, "Updated")
                updateExpectation.fulfill()
            }
        }.store(in: &cancellables)

        // When
        board.addCard(card, to: columnId)
        wait(for: [addExpectation], timeout: 1.0)

        var updated = card
        updated.title = "Updated"
        board.updateCard(updated, in: columnId)

        // Then
        wait(for: [updateExpectation], timeout: 1.0)

        let column = board.column(withId: columnId)!
        XCTAssertEqual(column.cards[0].title, "Updated")
    }

    func testReorderCard() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card1 = KanbanCard(title: "Card 1")
        let card2 = KanbanCard(title: "Card 2")
        let card3 = KanbanCard(title: "Card 3")

        let expectation = XCTestExpectation(description: "Cards added and reordered")
        expectation.expectedFulfillmentCount = 3

        board.cardEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // When
        board.addCard(card1, to: columnId)
        board.addCard(card2, to: columnId)
        board.addCard(card3, to: columnId)
        wait(for: [expectation], timeout: 1.0)

        // Reorder: move card at index 0 to index 2
        board.reorderCard(in: columnId, from: 0, to: 2)

        // Wait for reorder to complete
        let reorderWait = XCTestExpectation(description: "Wait for reorder")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            reorderWait.fulfill()
        }
        wait(for: [reorderWait], timeout: 1.0)

        // Then
        let column = board.column(withId: columnId)!
        XCTAssertEqual(column.cards[0].id, card2.id)
        XCTAssertEqual(column.cards[1].id, card1.id)
        XCTAssertEqual(column.cards[2].id, card3.id)
    }

    // MARK: - Column Operations Tests

    func testAddColumn() {
        // Given
        let board = KanbanBoard.standard()
        let initialCount = board.columns.count
        let newColumn = KanbanColumn(title: "Testing", order: 10)

        let expectation = XCTestExpectation(description: "Column added")

        // When
        board.addColumn(newColumn)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(board.columns.count, initialCount + 1)
        XCTAssertNotNil(board.column(withId: newColumn.id))
    }

    func testRemoveColumn() {
        // Given
        let board = KanbanBoard.standard()
        let columnToRemove = board.columns[0]

        let expectation = XCTestExpectation(description: "Column removed")

        // When
        board.removeColumn(id: columnToRemove.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertNil(board.column(withId: columnToRemove.id))
    }

    func testUpdateColumn() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        let expectation = XCTestExpectation(description: "Column updated")

        // When
        board.updateColumn(id: columnId, title: "New Title", limit: 5, color: "#ABCDEF")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        let column = board.column(withId: columnId)!
        XCTAssertEqual(column.title, "New Title")
        XCTAssertEqual(column.limit, 5)
        XCTAssertEqual(column.color, "#ABCDEF")
    }

    // MARK: - Lookup Methods Tests

    func testFindCard() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card = KanbanCard(title: "Test Card")

        let expectation = XCTestExpectation(description: "Card added")
        board.cardEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // When
        board.addCard(card, to: columnId)
        wait(for: [expectation], timeout: 1.0)

        let found = board.findCard(id: card.id)
        let notFound = board.findCard(id: UUID())

        // Then
        XCTAssertEqual(found?.card.id, card.id)
        XCTAssertEqual(found?.columnId, columnId)
        XCTAssertNil(notFound)
    }

    func testColumnWithId() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        // When
        let found = board.column(withId: columnId)
        let notFound = board.column(withId: UUID())

        // Then
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, columnId)
        XCTAssertNil(notFound)
    }

    func testCardsWithLabel() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        let expectation = XCTestExpectation(description: "Cards added")
        expectation.expectedFulfillmentCount = 3

        board.cardEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // When
        board.addCard(KanbanCard(title: "Bug 1", labels: [.bug]), to: columnId)
        board.addCard(KanbanCard(title: "Feature", labels: [.feature]), to: columnId)
        board.addCard(KanbanCard(title: "Bug 2", labels: [.bug]), to: columnId)
        wait(for: [expectation], timeout: 1.0)

        let bugCards = board.cards(withLabel: .bug)

        // Then
        XCTAssertEqual(bugCards.count, 2)
    }

    func testCardsAssignedTo() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id

        let expectation = XCTestExpectation(description: "Cards added")
        expectation.expectedFulfillmentCount = 3

        board.cardEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // When
        board.addCard(KanbanCard(title: "Rick's Card", assignee: "Rick"), to: columnId)
        board.addCard(KanbanCard(title: "Morty's Card", assignee: "Morty"), to: columnId)
        board.addCard(KanbanCard(title: "Another Rick Card", assignee: "Rick"), to: columnId)
        wait(for: [expectation], timeout: 1.0)

        let rickCards = board.cards(assignedTo: "Rick")

        // Then
        XCTAssertEqual(rickCards.count, 2)
    }

    func testCardWithTicketRef() {
        // Given
        let board = KanbanBoard.standard()
        let columnId = board.columns[0].id
        let card = KanbanCard(title: "Test", ticketRef: "RT-042")

        let expectation = XCTestExpectation(description: "Card added")
        board.cardEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // When
        board.addCard(card, to: columnId)
        wait(for: [expectation], timeout: 1.0)

        let found = board.card(withTicketRef: "RT-042")
        let notFound = board.card(withTicketRef: "RT-999")

        // Then
        XCTAssertEqual(found?.id, card.id)
        XCTAssertNil(notFound)
    }

    // MARK: - Factory Methods Tests

    func testStandardFactory() {
        let board = KanbanBoard.standard(title: "My Board", projectRef: "my-project")
        XCTAssertEqual(board.title, "My Board")
        XCTAssertEqual(board.projectRef, "my-project")
        XCTAssertEqual(board.columns.count, 4)
    }

    func testExtendedFactory() {
        let board = KanbanBoard.extended(title: "Extended Board")
        XCTAssertEqual(board.title, "Extended Board")
        XCTAssertEqual(board.columns.count, 5) // Includes Blocked column
    }

    func testSprintFactory() {
        let board = KanbanBoard.sprint(title: "Sprint 1")
        XCTAssertEqual(board.title, "Sprint 1")
        XCTAssertEqual(board.columns.count, 5)
        XCTAssertTrue(board.columns.contains { $0.title == "Sprint Backlog" })
        XCTAssertTrue(board.columns.contains { $0.title == "Code Review" })
        XCTAssertTrue(board.columns.contains { $0.title == "Testing" })
    }
}

// MARK: - CodableBoard Tests

class CodableBoardTests: XCTestCase {

    func testCodableBoardInit() {
        // Given
        let board = KanbanBoard(title: "Test", projectRef: "test-project")

        // When
        let codable = CodableBoard(from: board)

        // Then
        XCTAssertEqual(codable.id, board.id)
        XCTAssertEqual(codable.title, board.title)
        XCTAssertEqual(codable.columns.count, board.columns.count)
        XCTAssertEqual(codable.projectRef, board.projectRef)
    }

    func testCodableBoardEncodeDecode() throws {
        // Given
        let board = KanbanBoard(title: "Test Board", projectRef: "test")
        let codable = CodableBoard(from: board)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(codable)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodableBoard.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, codable.id)
        XCTAssertEqual(decoded.title, codable.title)
        XCTAssertEqual(decoded.projectRef, codable.projectRef)
    }
}
// MARK: - Drag and Drop Tests (RT-023)

extension KanbanBoardTests {

    // MARK: moveCard: cross-column

    func testMoveCardBetweenColumnsRemovesFromSource() {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]
        let inProgress = board.columns[1]

        let card = KanbanCard(title: "Drag me", status: .backlog)
        board.addCards([(card: card, columnId: backlog.id)])

        XCTAssertEqual(board.column(withId: backlog.id)?.cardCount, 1)
        XCTAssertEqual(board.column(withId: inProgress.id)?.cardCount, 0)

        // When – move cross-column
        let expectation = self.expectation(description: "card moved")
        board.moveCard(card.id, from: backlog.id, to: inProgress.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Then
        XCTAssertEqual(board.column(withId: backlog.id)?.cardCount, 0,
                       "Source column should be empty after move")
        XCTAssertEqual(board.column(withId: inProgress.id)?.cardCount, 1,
                       "Target column should have the moved card")
    }

    func testMoveCardBetweenColumnsAppearsInTarget() {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]
        let inProgress = board.columns[1]

        let card = KanbanCard(title: "Target test", status: .backlog)
        board.addCards([(card: card, columnId: backlog.id)])

        // When
        let expectation = self.expectation(description: "card moved")
        board.moveCard(card.id, from: backlog.id, to: inProgress.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Then
        let foundCard = board.column(withId: inProgress.id)?.cards.first { c in c.id == card.id }
        XCTAssertNotNil(foundCard, "Card should be findable in the target column")
        XCTAssertEqual(foundCard?.title, "Target test")
    }

    func testMoveCardPublishesMovedEvent() {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]
        let inProgress = board.columns[1]

        let card = KanbanCard(title: "Event test", status: .backlog)
        board.addCards([(card: card, columnId: backlog.id)])

        var receivedEvent: KanbanBoard.CardEvent?
        board.cardEvents
            .sink { event in receivedEvent = event }
            .store(in: &cancellables)

        // When
        let expectation = self.expectation(description: "event published")
        board.moveCard(card.id, from: backlog.id, to: inProgress.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Then
        guard case let .moved(cardId, fromColumnId, toColumnId) = receivedEvent else {
            XCTFail("Expected .moved event, got \(String(describing: receivedEvent))")
            return
        }
        XCTAssertEqual(cardId, card.id)
        XCTAssertEqual(fromColumnId, backlog.id)
        XCTAssertEqual(toColumnId, inProgress.id)
    }

    func testMoveCardWithInvalidSourceColumnIsNoOp() {
        // Given
        let board = KanbanBoard.standard()
        let inProgress = board.columns[1]
        let fakeSourceId = UUID()
        let card = KanbanCard(title: "Ghost card", status: .backlog)
        // Card is NOT added to any column

        let initialCount = board.column(withId: inProgress.id)?.cardCount ?? 0

        // When – non-existent source column
        let expectation = self.expectation(description: "no-op settled")
        board.moveCard(card.id, from: fakeSourceId, to: inProgress.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Then – board state unchanged
        XCTAssertEqual(board.column(withId: inProgress.id)?.cardCount, initialCount)
    }

    func testMoveCardToSameColumnIsNoOp() {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]

        let card = KanbanCard(title: "Same column", status: .backlog)
        board.addCards([(card: card, columnId: backlog.id)])

        // When – move to same column
        let expectation = self.expectation(description: "settled")
        board.moveCard(card.id, from: backlog.id, to: backlog.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Then – card is still there (moved to same position)
        // The board implementation moves within the same column; card count stays 1
        XCTAssertEqual(board.column(withId: backlog.id)?.cardCount, 1)
        XCTAssertNotNil(board.column(withId: backlog.id)?.cards.first { c in c.id == card.id })
    }

    func testMoveCardPreservesRemainingCardsInSourceColumn() {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]
        let done = board.columns[3]

        let card1 = KanbanCard(title: "Stay here", status: .backlog)
        let card2 = KanbanCard(title: "Move me", status: .backlog)
        board.addCards([
            (card: card1, columnId: backlog.id),
            (card: card2, columnId: backlog.id)
        ])
        XCTAssertEqual(board.column(withId: backlog.id)?.cardCount, 2)

        // When
        let expectation = self.expectation(description: "card2 moved")
        board.moveCard(card2.id, from: backlog.id, to: done.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Then – card1 stays, card2 is gone from source
        let backlogCards = board.column(withId: backlog.id)?.cards ?? []
        XCTAssertEqual(backlogCards.count, 1)
        XCTAssertEqual(backlogCards.first?.id, card1.id)
        XCTAssertEqual(board.column(withId: done.id)?.cardCount, 1)
    }

    // MARK: Persistence after move

    func testMoveCardPersistedViaJSONRoundtrip() throws {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]
        let review = board.columns[2]

        let card = KanbanCard(title: "Persist after move", status: .backlog)
        board.addCards([(card: card, columnId: backlog.id)])

        let expectation = self.expectation(description: "move settled")
        board.moveCard(card.id, from: backlog.id, to: review.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
        waitForExpectations(timeout: 1)

        // When – round-trip through JSON
        let data = try board.toJSONData()
        let restored = try KanbanBoard.fromJSONData(data)

        // Then
        XCTAssertEqual(restored.column(withId: backlog.id)?.cardCount, 0)
        let restoredCard = restored.column(withId: review.id)?.cards.first { c in c.id == card.id }
        XCTAssertNotNil(restoredCard, "Card should be in review column after JSON round-trip")
    }

    // MARK: Reorder within column

    func testReorderCardWithinColumn() {
        // Given
        let board = KanbanBoard.standard()
        let backlog = board.columns[0]

        let card1 = KanbanCard(title: "First", status: .backlog)
        let card2 = KanbanCard(title: "Second", status: .backlog)
        let card3 = KanbanCard(title: "Third", status: .backlog)

        board.addCards([
            (card: card1, columnId: backlog.id),
            (card: card2, columnId: backlog.id),
            (card: card3, columnId: backlog.id)
        ])

        // When – move Third to position 0
        let expectation = self.expectation(description: "reorder settled")
        board.reorderCard(in: backlog.id, from: 2, to: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
        waitForExpectations(timeout: 1)

        // Then – Third should now be first
        let cards = board.column(withId: backlog.id)?.cards ?? []
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards[0].title, "Third")
        XCTAssertEqual(cards[1].title, "First")
    }
}
