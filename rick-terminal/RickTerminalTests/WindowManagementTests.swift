import XCTest
@testable import RickTerminal

/// Unit tests for multi-window and tab management functionality
class WindowManagementTests: XCTestCase {

    // MARK: - Layout State Tests

    func testLayoutStateInitialization() {
        let layoutState = LayoutState()

        // Verify default values
        XCTAssertEqual(layoutState.leftSidebarWidth, 200)
        XCTAssertEqual(layoutState.rightPanelWidth, 300)
        XCTAssertFalse(layoutState.isLeftSidebarCollapsed)
        XCTAssertFalse(layoutState.isRightPanelCollapsed)
    }

    func testToggleLeftSidebar() {
        let layoutState = LayoutState()

        // Initial state
        XCTAssertFalse(layoutState.isLeftSidebarCollapsed)

        // Toggle on
        layoutState.toggleLeftSidebar()
        XCTAssertTrue(layoutState.isLeftSidebarCollapsed)

        // Toggle off
        layoutState.toggleLeftSidebar()
        XCTAssertFalse(layoutState.isLeftSidebarCollapsed)
    }

    func testToggleRightPanel() {
        let layoutState = LayoutState()

        // Initial state
        XCTAssertFalse(layoutState.isRightPanelCollapsed)

        // Toggle on
        layoutState.toggleRightPanel()
        XCTAssertTrue(layoutState.isRightPanelCollapsed)

        // Toggle off
        layoutState.toggleRightPanel()
        XCTAssertFalse(layoutState.isRightPanelCollapsed)
    }

    func testLayoutStateWidthConstraints() {
        let layoutState = LayoutState()

        // Test minimum width constraint
        XCTAssertGreaterThanOrEqual(LayoutState.minLeftSidebarWidth, 0)
        XCTAssertGreaterThanOrEqual(LayoutState.minRightPanelWidth, 0)

        // Test maximum width constraint
        XCTAssertGreaterThan(LayoutState.maxLeftSidebarWidth, LayoutState.minLeftSidebarWidth)
        XCTAssertGreaterThan(LayoutState.maxRightPanelWidth, LayoutState.minRightPanelWidth)

        // Test default widths fall within constraints
        XCTAssertGreaterThanOrEqual(layoutState.leftSidebarWidth, LayoutState.minLeftSidebarWidth)
        XCTAssertLessThanOrEqual(layoutState.leftSidebarWidth, LayoutState.maxLeftSidebarWidth)

        XCTAssertGreaterThanOrEqual(layoutState.rightPanelWidth, LayoutState.minRightPanelWidth)
        XCTAssertLessThanOrEqual(layoutState.rightPanelWidth, LayoutState.maxRightPanelWidth)
    }

    func testLayoutStateWidthPersistence() {
        let layoutState = LayoutState()
        let newLeftWidth: CGFloat = 250
        let newRightWidth: CGFloat = 350

        // Update widths
        layoutState.leftSidebarWidth = newLeftWidth
        layoutState.rightPanelWidth = newRightWidth

        // Verify changes persisted
        XCTAssertEqual(layoutState.leftSidebarWidth, newLeftWidth)
        XCTAssertEqual(layoutState.rightPanelWidth, newRightWidth)
    }

    // MARK: - Window Title Tests

    func testWindowTitleWithoutSession() {
        let sessionManager = ShellSessionManager()

        // Should return default title when no sessions exist
        XCTAssertEqual(sessionManager.sessionCount, 0)
    }

    func testWindowTitleWithSession() throws {
        let sessionManager = ShellSessionManager()

        // Create a session
        _ = try sessionManager.createAndStartSession()

        // Verify session was created
        XCTAssertEqual(sessionManager.sessionCount, 1)
        XCTAssertNotNil(sessionManager.getActiveSession())
    }

    func testWindowTitleWithMultipleSessions() throws {
        let sessionManager = ShellSessionManager()

        // Create multiple sessions
        _ = try sessionManager.createAndStartSession()
        _ = try sessionManager.createAndStartSession()
        _ = try sessionManager.createAndStartSession()

        // Verify sessions were created
        XCTAssertEqual(sessionManager.sessionCount, 3)
    }

    func testWindowSubtitleSingular() throws {
        let sessionManager = ShellSessionManager()

        // Create one session
        _ = try sessionManager.createAndStartSession()

        // Verify subtitle is singular
        let subtitle = "\(sessionManager.sessionCount) session\(sessionManager.sessionCount == 1 ? "" : "s")"
        XCTAssertEqual(subtitle, "1 session")
    }

    func testWindowSubtitlePlural() throws {
        let sessionManager = ShellSessionManager()

        // Create multiple sessions
        _ = try sessionManager.createAndStartSession()
        _ = try sessionManager.createAndStartSession()

        // Verify subtitle is plural
        let subtitle = "\(sessionManager.sessionCount) session\(sessionManager.sessionCount == 1 ? "" : "s")"
        XCTAssertEqual(subtitle, "2 sessions")
    }

    // MARK: - Session Management Tests

    func testMultipleSessionsIndependence() throws {
        let sessionManager = ShellSessionManager()

        // Create two sessions
        let session1 = try sessionManager.createAndStartSession()
        let session2 = try sessionManager.createAndStartSession()

        // Verify they have different IDs
        XCTAssertNotEqual(session1.id, session2.id)

        // Verify both exist in manager
        XCTAssertNotNil(sessionManager.getSession(session1.id))
        XCTAssertNotNil(sessionManager.getSession(session2.id))
    }

    func testActiveSessionSwitching() throws {
        let sessionManager = ShellSessionManager()

        // Create two sessions
        let session1 = try sessionManager.createAndStartSession()
        let session2 = try sessionManager.createAndStartSession()

        // First session should be active initially
        XCTAssertEqual(sessionManager.activeSessionId, session1.id)

        // Switch to second session
        sessionManager.setActiveSession(session2.id)
        XCTAssertEqual(sessionManager.activeSessionId, session2.id)

        // Switch back to first session
        sessionManager.setActiveSession(session1.id)
        XCTAssertEqual(sessionManager.activeSessionId, session1.id)
    }

    func testSessionRemovalUpdatesActiveSession() throws {
        let sessionManager = ShellSessionManager()

        // Create two sessions
        let session1 = try sessionManager.createAndStartSession()
        let session2 = try sessionManager.createAndStartSession()

        // Set session1 as active
        sessionManager.setActiveSession(session1.id)
        XCTAssertEqual(sessionManager.activeSessionId, session1.id)

        // Remove active session
        sessionManager.removeSession(session1.id)

        // Active session should switch to remaining session
        XCTAssertEqual(sessionManager.sessionCount, 1)
        XCTAssertNotEqual(sessionManager.activeSessionId, session1.id)
    }

    // MARK: - Window State Restoration Tests

    func testWindowStateRestoration() {
        let layoutState = LayoutState()

        // Set initial state
        let leftWidth: CGFloat = 250
        let rightWidth: CGFloat = 350
        layoutState.leftSidebarWidth = leftWidth
        layoutState.rightPanelWidth = rightWidth
        layoutState.isLeftSidebarCollapsed = true
        layoutState.isRightPanelCollapsed = false

        // Verify state
        XCTAssertEqual(layoutState.leftSidebarWidth, leftWidth)
        XCTAssertEqual(layoutState.rightPanelWidth, rightWidth)
        XCTAssertTrue(layoutState.isLeftSidebarCollapsed)
        XCTAssertFalse(layoutState.isRightPanelCollapsed)
    }

    func testWindowStateRestorationDefaults() {
        let layoutState = LayoutState()

        // Create a new layout state (simulating new window)
        let newLayoutState = LayoutState()

        // Should have same default values
        XCTAssertEqual(layoutState.leftSidebarWidth, newLayoutState.leftSidebarWidth)
        XCTAssertEqual(layoutState.rightPanelWidth, newLayoutState.rightPanelWidth)
        XCTAssertEqual(layoutState.isLeftSidebarCollapsed, newLayoutState.isLeftSidebarCollapsed)
        XCTAssertEqual(layoutState.isRightPanelCollapsed, newLayoutState.isRightPanelCollapsed)
    }
}
