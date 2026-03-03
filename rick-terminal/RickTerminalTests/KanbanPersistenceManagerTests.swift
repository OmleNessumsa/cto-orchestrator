import XCTest
import Combine
@testable import RickTerminal

final class KanbanPersistenceManagerTests: XCTestCase {
    var persistence: KanbanPersistenceManager!
    var testBoard: KanbanBoard!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        persistence = KanbanPersistenceManager.shared
        cancellables = Set<AnyCancellable>()

        // Clean up any existing test data
        try? persistence.deleteAllBoards()

        // Create a test board
        testBoard = KanbanBoard.standard(
            title: "Test Board",
            projectRef: "test-project"
        )
    }

    override func tearDown() {
        // Clean up test data
        try? persistence.deleteAllBoards()
        cancellables.removeAll()
        testBoard = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Basic Save/Load Tests

    func testSaveAndLoadBoard() throws {
        // Save board
        try persistence.saveBoard(testBoard)

        // Verify board exists
        XCTAssertTrue(persistence.boardExists(testBoard.id))

        // Load board
        let loadedBoard = try persistence.loadBoard(testBoard.id)

        // Verify loaded board matches original
        XCTAssertEqual(loadedBoard.id, testBoard.id)
        XCTAssertEqual(loadedBoard.title, testBoard.title)
        XCTAssertEqual(loadedBoard.projectRef, testBoard.projectRef)
        XCTAssertEqual(loadedBoard.columns.count, testBoard.columns.count)
    }

    func testSaveAndLoadBoardWithCards() throws {
        // Add some cards to the board
        let card1 = KanbanCard(
            title: "Test Card 1",
            description: "Description 1",
            status: .backlog
        )
        let card2 = KanbanCard(
            title: "Test Card 2",
            description: "Description 2",
            status: .inProgress
        )

        let backlogColumn = testBoard.columns.first { $0.title == "Backlog" }!
        let inProgressColumn = testBoard.columns.first { $0.title == "In Progress" }!

        testBoard.addCard(card1, to: backlogColumn.id)
        testBoard.addCard(card2, to: inProgressColumn.id)

        // Wait for async operations
        let expectation = XCTestExpectation(description: "Cards added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Save board
        try persistence.saveBoard(testBoard)

        // Load board
        let loadedBoard = try persistence.loadBoard(testBoard.id)

        // Verify cards were persisted
        XCTAssertEqual(loadedBoard.totalCards, 2)
        let loadedBacklog = loadedBoard.columns.first { $0.title == "Backlog" }!
        let loadedInProgress = loadedBoard.columns.first { $0.title == "In Progress" }!
        XCTAssertEqual(loadedBacklog.cards.count, 1)
        XCTAssertEqual(loadedInProgress.cards.count, 1)
    }

    // MARK: - Multiple Boards Tests

    func testLoadMultipleBoards() throws {
        // Create and save multiple boards
        let board1 = KanbanBoard.standard(title: "Board 1", projectRef: "project-1")
        let board2 = KanbanBoard.standard(title: "Board 2", projectRef: "project-1")
        let board3 = KanbanBoard.standard(title: "Board 3", projectRef: "project-2")

        try persistence.saveBoard(board1)
        try persistence.saveBoard(board2)
        try persistence.saveBoard(board3)

        // Load all boards
        let allBoards = persistence.loadAllBoards()
        XCTAssertEqual(allBoards.count, 3)

        // Load boards for specific project
        let project1Boards = persistence.loadBoards(forProject: "project-1")
        XCTAssertEqual(project1Boards.count, 2)

        let project2Boards = persistence.loadBoards(forProject: "project-2")
        XCTAssertEqual(project2Boards.count, 1)
    }

    // MARK: - Current Board Tests

    func testSaveAndLoadCurrentBoardId() {
        // Save current board ID
        persistence.saveCurrentBoardId(testBoard.id)

        // Load current board ID
        let loadedId = persistence.loadCurrentBoardId()
        XCTAssertEqual(loadedId, testBoard.id)
    }

    func testClearCurrentBoardId() {
        // Save then clear
        persistence.saveCurrentBoardId(testBoard.id)
        persistence.saveCurrentBoardId(nil)

        // Verify it's cleared
        let loadedId = persistence.loadCurrentBoardId()
        XCTAssertNil(loadedId)
    }

    // MARK: - Corrupted File Tests

    func testLoadCorruptedFileGracefully() throws {
        // Save a valid board first
        try persistence.saveBoard(testBoard)

        // Get the file URL and corrupt it
        let fileURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("RickTerminal/Boards/\(testBoard.id.uuidString).json")

        let corruptedData = "{ invalid json }".data(using: .utf8)!
        try corruptedData.write(to: fileURL)

        // Try to load - should throw corrupted file error
        XCTAssertThrowsError(try persistence.loadBoard(testBoard.id)) { error in
            if case PersistenceError.corruptedFile = error {
                // Expected error type
            } else {
                XCTFail("Expected corruptedFile error, got \(error)")
            }
        }
    }

    func testLoadBoardOrDefaultWithCorruption() throws {
        // Save a valid board first
        try persistence.saveBoard(testBoard)

        // Corrupt the file
        let fileURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("RickTerminal/Boards/\(testBoard.id.uuidString).json")

        let corruptedData = "{ invalid json }".data(using: .utf8)!
        try corruptedData.write(to: fileURL)

        // Load with fallback - should return default board
        let board = persistence.loadBoardOrDefault(testBoard.id, projectRef: "test-project")

        // Verify we got a valid board (even if corrupted was backed up)
        XCTAssertNotNil(board)
        XCTAssertEqual(board.projectRef, "test-project")
    }

    // MARK: - Debounced Save Tests

    func testDebouncedSave() throws {
        // Start observing the board
        persistence.observeBoard(testBoard)

        // Modify the board multiple times rapidly
        let card = KanbanCard(title: "Test Card", description: "Test", status: .backlog)
        let columnId = testBoard.columns.first!.id

        testBoard.addCard(card, to: columnId)

        // Wait for debounce period
        let expectation = XCTestExpectation(description: "Debounced save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)

        // Verify board was saved
        XCTAssertTrue(persistence.boardExists(testBoard.id))

        // Load and verify
        let loadedBoard = try persistence.loadBoard(testBoard.id)
        XCTAssertEqual(loadedBoard.totalCards, 1)
    }

    // MARK: - Delete Tests

    func testDeleteBoard() throws {
        // Save board
        try persistence.saveBoard(testBoard)
        XCTAssertTrue(persistence.boardExists(testBoard.id))

        // Delete board
        try persistence.deleteBoard(testBoard.id)
        XCTAssertFalse(persistence.boardExists(testBoard.id))
    }

    func testDeleteAllBoards() throws {
        // Save multiple boards
        let board1 = KanbanBoard.standard(title: "Board 1")
        let board2 = KanbanBoard.standard(title: "Board 2")

        try persistence.saveBoard(board1)
        try persistence.saveBoard(board2)
        persistence.saveCurrentBoardId(board1.id)

        XCTAssertEqual(persistence.boardCount, 2)

        // Delete all
        try persistence.deleteAllBoards()

        XCTAssertEqual(persistence.boardCount, 0)
        XCTAssertNil(persistence.loadCurrentBoardId())
    }

    // MARK: - Statistics Tests

    func testBoardCount() throws {
        XCTAssertEqual(persistence.boardCount, 0)

        try persistence.saveBoard(testBoard)
        XCTAssertEqual(persistence.boardCount, 1)

        let board2 = KanbanBoard.standard(title: "Board 2")
        try persistence.saveBoard(board2)
        XCTAssertEqual(persistence.boardCount, 2)
    }

    func testBoardExists() throws {
        XCTAssertFalse(persistence.boardExists(testBoard.id))

        try persistence.saveBoard(testBoard)
        XCTAssertTrue(persistence.boardExists(testBoard.id))

        try persistence.deleteBoard(testBoard.id)
        XCTAssertFalse(persistence.boardExists(testBoard.id))
    }

    // MARK: - Thread Safety Tests

    func testConcurrentSaves() throws {
        let expectation = XCTestExpectation(description: "Concurrent saves completed")
        expectation.expectedFulfillmentCount = 10

        // Perform multiple concurrent saves
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let board = KanbanBoard.standard(title: "Board \(index)")
            try? persistence.saveBoard(board)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify all boards were saved
        XCTAssertEqual(persistence.boardCount, 10)
    }

    // MARK: - Integration Tests

    func testFullPersistenceLifecycle() throws {
        // Create board
        let board = KanbanBoard.standard(title: "Lifecycle Test", projectRef: "lifecycle")

        // Add cards
        let card1 = KanbanCard(title: "Card 1", description: "Test 1", status: .backlog)
        let card2 = KanbanCard(title: "Card 2", description: "Test 2", status: .inProgress)

        let backlogCol = board.columns.first { $0.title == "Backlog" }!
        let progressCol = board.columns.first { $0.title == "In Progress" }!

        board.addCard(card1, to: backlogCol.id)
        board.addCard(card2, to: progressCol.id)

        // Wait for async operations
        Thread.sleep(forTimeInterval: 0.2)

        // Save board
        try persistence.saveBoard(board)
        persistence.saveCurrentBoardId(board.id)

        // Simulate app restart - load board
        let currentId = persistence.loadCurrentBoardId()
        XCTAssertEqual(currentId, board.id)

        let loadedBoard = try persistence.loadBoard(currentId!)

        // Verify state
        XCTAssertEqual(loadedBoard.title, "Lifecycle Test")
        XCTAssertEqual(loadedBoard.totalCards, 2)

        // Move card
        let loadedCard1 = loadedBoard.allCards.first { $0.title == "Card 1" }!
        let loadedProgressCol = loadedBoard.columns.first { $0.title == "In Progress" }!

        loadedBoard.moveCard(
            loadedCard1.id,
            from: backlogCol.id,
            to: loadedProgressCol.id
        )

        Thread.sleep(forTimeInterval: 0.2)

        // Save again
        try persistence.saveBoard(loadedBoard)

        // Load again and verify move
        let finalBoard = try persistence.loadBoard(board.id)
        let finalProgressCol = finalBoard.columns.first { $0.title == "In Progress" }!
        XCTAssertEqual(finalProgressCol.cards.count, 3) // card2 + card1 moved
    }
}
