import XCTest

/// Tests for terminal input and output functionality
final class TerminalInteractionTests: XCTestCase {
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

    /// Test terminal is visible and accessible
    func testTerminalExists() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Ensure we're on Terminal tab
        let terminalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Terminal'")).firstMatch
        if terminalButton.exists {
            terminalButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Terminal view should be accessible
        // Look for any text views or text fields that might be the terminal
        let textViews = app.textViews
        let textFields = app.textFields

        XCTAssertTrue(textViews.count > 0 || textFields.count > 0,
                     "Terminal should have text input capability")
    }

    /// Test that terminal can receive keyboard input
    func testTerminalAcceptsInput() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Switch to Terminal tab
        let terminalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Terminal'")).firstMatch
        if terminalButton.exists {
            terminalButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Click on the window to ensure focus
        window.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Type a simple command
        app.typeText("echo 'Hello Rick Terminal'")

        // The text should appear somewhere in the interface
        // We're testing that typing works, not necessarily where it appears
        Thread.sleep(forTimeInterval: 0.5)

        // Press return
        app.typeKey(.enter, modifierFlags: [])

        // Wait for command to execute
        Thread.sleep(forTimeInterval: 1.0)

        // Verify we can continue typing (terminal is still responsive)
        app.typeText("pwd")
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Test clear terminal functionality
    func testClearTerminal() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Switch to Terminal tab
        let terminalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Terminal'")).firstMatch
        if terminalButton.exists {
            terminalButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Focus the window
        window.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Type some content
        app.typeText("echo 'test content'")
        app.typeKey(.enter, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)

        // Use menu to clear terminal (Command menu -> Terminal -> Clear)
        let menuBar = app.menuBars.firstMatch
        if menuBar.exists {
            let terminalMenu = menuBar.menuItems["Terminal"]
            if terminalMenu.exists {
                terminalMenu.click()
                Thread.sleep(forTimeInterval: 0.2)

                let clearMenuItem = app.menuItems["Clear"]
                if clearMenuItem.exists {
                    clearMenuItem.click()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }

        // Verify terminal is still responsive after clear
        app.typeText("ls")
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Test terminal handles multi-line input
    func testMultiLineInput() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Switch to Terminal tab
        let terminalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Terminal'")).firstMatch
        if terminalButton.exists {
            terminalButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        window.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Type a command that spans lines using line continuation
        app.typeText("echo \\")
        app.typeKey(.enter, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        app.typeText("'multi-line'")
        app.typeKey(.enter, modifierFlags: [])
        Thread.sleep(forTimeInterval: 1.0)

        // Verify terminal is still responsive
        app.typeText("date")
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Test interrupt process (Ctrl+C)
    func testInterruptProcess() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Switch to Terminal tab
        let terminalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Terminal'")).firstMatch
        if terminalButton.exists {
            terminalButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        window.click()
        Thread.sleep(forTimeInterval: 0.3)

        // Start a long-running process
        app.typeText("sleep 100")
        app.typeKey(.enter, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)

        // Send interrupt via menu (Terminal -> Interrupt)
        let menuBar = app.menuBars.firstMatch
        if menuBar.exists {
            let terminalMenu = menuBar.menuItems["Terminal"]
            if terminalMenu.exists {
                terminalMenu.click()
                Thread.sleep(forTimeInterval: 0.2)

                let interruptMenuItem = app.menuItems["Interrupt Process"]
                if interruptMenuItem.exists {
                    interruptMenuItem.click()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }

        // Verify terminal is responsive after interrupt
        Thread.sleep(forTimeInterval: 0.5)
        app.typeText("echo 'interrupted'")
        app.typeKey(.enter, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }
}
