import XCTest
@testable import RickTerminal

/// Unit tests for session persistence functionality
class SessionPersistenceTests: XCTestCase {
    var persistence: SessionPersistenceManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = SessionPersistenceManager.shared
        // Clean up any existing sessions before each test
        try? persistence.deleteAllSessions()
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        try? persistence.deleteAllSessions()
        persistence = nil
        try super.tearDownWithError()
    }

    // MARK: - Session State Tests

    func testSaveAndLoadSession() throws {
        // Given
        let sessionId = UUID()
        let state = PersistedSessionState(
            id: sessionId,
            workingDirectory: "/Users/test/project",
            shellType: "/bin/zsh",
            createdAt: Date(),
            lastAccessedAt: Date()
        )

        // When
        try persistence.saveSession(state)

        // Then
        let loadedState = try persistence.loadSession(sessionId)
        XCTAssertEqual(loadedState.id, state.id)
        XCTAssertEqual(loadedState.workingDirectory, state.workingDirectory)
        XCTAssertEqual(loadedState.shellType, state.shellType)
    }

    func testLoadNonExistentSession() {
        // Given
        let nonExistentId = UUID()

        // When/Then
        XCTAssertThrowsError(try persistence.loadSession(nonExistentId))
    }

    func testSaveMultipleSessions() throws {
        // Given
        let states = [
            PersistedSessionState(
                id: UUID(),
                workingDirectory: "/Users/test/project1",
                shellType: "/bin/zsh",
                createdAt: Date(),
                lastAccessedAt: Date()
            ),
            PersistedSessionState(
                id: UUID(),
                workingDirectory: "/Users/test/project2",
                shellType: "/bin/bash",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        ]

        // When
        try persistence.saveSessions(states)

        // Then
        let loadedSessions = persistence.loadAllSessions()
        XCTAssertEqual(loadedSessions.count, 2)
    }

    func testLoadAllSessions() throws {
        // Given
        let count = 3
        for i in 0..<count {
            let state = PersistedSessionState(
                id: UUID(),
                workingDirectory: "/Users/test/project\(i)",
                shellType: "/bin/zsh",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
            try persistence.saveSession(state)
        }

        // When
        let loadedSessions = persistence.loadAllSessions()

        // Then
        XCTAssertEqual(loadedSessions.count, count)
    }

    func testSessionsSortedByLastAccessed() throws {
        // Given
        let now = Date()
        let old = now.addingTimeInterval(-3600)
        let older = now.addingTimeInterval(-7200)

        let states = [
            PersistedSessionState(
                id: UUID(),
                workingDirectory: "/Users/test/old",
                shellType: "/bin/zsh",
                createdAt: older,
                lastAccessedAt: old
            ),
            PersistedSessionState(
                id: UUID(),
                workingDirectory: "/Users/test/new",
                shellType: "/bin/zsh",
                createdAt: now,
                lastAccessedAt: now
            )
        ]

        try persistence.saveSessions(states)

        // When
        let loadedSessions = persistence.loadAllSessions()

        // Then
        XCTAssertEqual(loadedSessions.first?.workingDirectory, "/Users/test/new")
        XCTAssertEqual(loadedSessions.last?.workingDirectory, "/Users/test/old")
    }

    // MARK: - Delete Tests

    func testDeleteSession() throws {
        // Given
        let sessionId = UUID()
        let state = PersistedSessionState(
            id: sessionId,
            workingDirectory: "/Users/test/project",
            shellType: "/bin/zsh",
            createdAt: Date(),
            lastAccessedAt: Date()
        )
        try persistence.saveSession(state)

        // When
        try persistence.deleteSession(sessionId)

        // Then
        XCTAssertFalse(persistence.sessionExists(sessionId))
    }

    func testDeleteMultipleSessions() throws {
        // Given
        let session1 = UUID()
        let session2 = UUID()
        let session3 = UUID()

        try persistence.saveSessions([
            PersistedSessionState(id: session1, workingDirectory: "/test1", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date()),
            PersistedSessionState(id: session2, workingDirectory: "/test2", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date()),
            PersistedSessionState(id: session3, workingDirectory: "/test3", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date())
        ])

        // When
        try persistence.deleteSessions([session1, session2])

        // Then
        let remaining = persistence.loadAllSessions()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, session3)
    }

    func testDeleteAllSessions() throws {
        // Given
        try persistence.saveSessions([
            PersistedSessionState(id: UUID(), workingDirectory: "/test1", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date()),
            PersistedSessionState(id: UUID(), workingDirectory: "/test2", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date())
        ])

        // When
        try persistence.deleteAllSessions()

        // Then
        XCTAssertEqual(persistence.sessionCount, 0)
    }

    // MARK: - Current Session Tests

    func testSaveAndLoadCurrentSession() {
        // Given
        let sessionId = UUID()

        // When
        persistence.saveCurrentSession(sessionId)

        // Then
        let loadedId = persistence.loadCurrentSessionId()
        XCTAssertEqual(loadedId, sessionId)
    }

    func testSaveNilCurrentSession() {
        // Given
        persistence.saveCurrentSession(UUID())

        // When
        persistence.saveCurrentSession(nil)

        // Then
        XCTAssertNil(persistence.loadCurrentSessionId())
    }

    // MARK: - Cleanup Tests

    func testCleanupOldSessions() throws {
        // Given
        let now = Date()
        let old = now.addingTimeInterval(-31 * 24 * 3600) // 31 days ago
        let recent = now.addingTimeInterval(-10 * 24 * 3600) // 10 days ago

        try persistence.saveSessions([
            PersistedSessionState(
                id: UUID(),
                workingDirectory: "/old",
                shellType: "/bin/zsh",
                createdAt: old,
                lastAccessedAt: old
            ),
            PersistedSessionState(
                id: UUID(),
                workingDirectory: "/recent",
                shellType: "/bin/zsh",
                createdAt: recent,
                lastAccessedAt: recent
            )
        ])

        // When
        try persistence.cleanupOldSessions(olderThanDays: 30)

        // Then
        let remaining = persistence.loadAllSessions()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.workingDirectory, "/recent")
    }

    // MARK: - Session Exists Tests

    func testSessionExists() throws {
        // Given
        let sessionId = UUID()
        let state = PersistedSessionState(
            id: sessionId,
            workingDirectory: "/test",
            shellType: "/bin/zsh",
            createdAt: Date(),
            lastAccessedAt: Date()
        )
        try persistence.saveSession(state)

        // When/Then
        XCTAssertTrue(persistence.sessionExists(sessionId))
        XCTAssertFalse(persistence.sessionExists(UUID()))
    }

    // MARK: - Session Count Tests

    func testSessionCount() throws {
        // Given
        XCTAssertEqual(persistence.sessionCount, 0)

        // When
        try persistence.saveSessions([
            PersistedSessionState(id: UUID(), workingDirectory: "/test1", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date()),
            PersistedSessionState(id: UUID(), workingDirectory: "/test2", shellType: "/bin/zsh", createdAt: Date(), lastAccessedAt: Date())
        ])

        // Then
        XCTAssertEqual(persistence.sessionCount, 2)
    }
}

// MARK: - ShellSession Extension Tests

class ShellSessionPersistenceExtensionTests: XCTestCase {
    func testToPersistedState() {
        // Given
        let session = ShellSession(workingDirectory: "/Users/test/project", shell: .zsh)

        // When
        let state = session.toPersistedState()

        // Then
        XCTAssertEqual(state.id, session.id)
        XCTAssertEqual(state.workingDirectory, session.workingDirectory)
        XCTAssertEqual(state.shellType, session.shell.rawValue)
    }

    func testUpdatePersistedState() {
        // Given
        let session = ShellSession(workingDirectory: "/Users/test/project", shell: .zsh)
        let originalState = session.toPersistedState()

        // Wait a bit to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.1)

        // When
        let updatedState = session.updatePersistedState(originalState)

        // Then
        XCTAssertEqual(updatedState.id, originalState.id)
        XCTAssertGreaterThan(updatedState.lastAccessedAt, originalState.lastAccessedAt)
    }
}
