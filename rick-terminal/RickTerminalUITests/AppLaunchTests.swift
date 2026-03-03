import XCTest

/// Tests for app launch and basic initialization
final class AppLaunchTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Test that the app launches successfully
    func testAppLaunches() throws {
        // Verify app is running
        XCTAssertTrue(app.state == .runningForeground)

        // Wait for main window to appear
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should appear within 5 seconds")

        // Verify window is visible and hittable
        XCTAssertTrue(window.exists, "Main window should exist")
    }

    /// Test that key UI elements are present on launch
    func testMainUIElementsPresent() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Check for Terminal tab (in center panel toggle)
        let terminalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Terminal'")).firstMatch
        XCTAssertTrue(terminalButton.waitForExistence(timeout: 3), "Terminal button should exist")

        // Check for Editor tab
        let editorButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Editor'")).firstMatch
        XCTAssertTrue(editorButton.waitForExistence(timeout: 3), "Editor button should exist")

        // Check for sidebar toggle buttons
        let sidebarToggles = app.buttons.matching(NSPredicate(format: "label CONTAINS 'sidebar'"))
        XCTAssertGreaterThanOrEqual(sidebarToggles.count, 1, "At least one sidebar toggle should exist")
    }

    /// Test that the app's title is correct
    func testWindowTitle() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // The window title should contain "Rick Terminal"
        XCTAssertTrue(window.title.contains("Rick Terminal"), "Window title should contain 'Rick Terminal'")
    }

    /// Test that panels can be collapsed and expanded
    func testPanelCollapsing() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Find sidebar toggle buttons
        let leftSidebarToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'File Browser'")).firstMatch
        let rightSidebarToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Kanban'")).firstMatch

        // Toggle left sidebar if it exists
        if leftSidebarToggle.exists {
            let initialLabel = leftSidebarToggle.label
            leftSidebarToggle.tap()

            // Wait a moment for animation
            Thread.sleep(forTimeInterval: 0.3)

            // Label should change after toggle
            let newLabel = leftSidebarToggle.label
            XCTAssertNotEqual(initialLabel, newLabel, "Sidebar toggle label should change")

            // Toggle back
            leftSidebarToggle.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Toggle right sidebar if it exists
        if rightSidebarToggle.exists {
            let initialLabel = rightSidebarToggle.label
            rightSidebarToggle.tap()

            // Wait a moment for animation
            Thread.sleep(forTimeInterval: 0.3)

            // Label should change after toggle
            let newLabel = rightSidebarToggle.label
            XCTAssertNotEqual(initialLabel, newLabel, "Sidebar toggle label should change")

            // Toggle back
            rightSidebarToggle.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
}
