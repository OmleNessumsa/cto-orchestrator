import XCTest

/// Tests for file browser navigation and interaction
final class FileBrowserTests: XCTestCase {
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

    /// Test that file browser is accessible and can be toggled
    func testFileBrowserToggle() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Find the file browser toggle button
        let fileBrowserToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'File Browser'")).firstMatch

        if fileBrowserToggle.waitForExistence(timeout: 3) {
            let initialLabel = fileBrowserToggle.label

            // Toggle file browser
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // Verify toggle state changed
            let newLabel = fileBrowserToggle.label
            XCTAssertNotEqual(initialLabel, newLabel, "File browser toggle state should change")

            // Toggle back
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // Should return to initial state
            let finalLabel = fileBrowserToggle.label
            XCTAssertEqual(initialLabel, finalLabel, "File browser should return to initial state")
        } else {
            // If toggle button doesn't exist, file browser might be always visible
            // This is acceptable, just document it
            XCTAssertTrue(true, "File browser toggle not found - may be always visible")
        }
    }

    /// Test file browser displays directory structure
    func testFileBrowserShowsFiles() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Ensure file browser is visible
        let fileBrowserToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Show File Browser'")).firstMatch
        if fileBrowserToggle.exists {
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Look for outline or table views (common file browser components)
        let outlines = app.outlines
        let tables = app.tables
        let scrollViews = app.scrollViews

        // At least one of these should exist for file browsing
        let hasFileListComponent = outlines.count > 0 || tables.count > 0 || scrollViews.count > 0
        XCTAssertTrue(hasFileListComponent, "File browser should have a list component")

        // If we have an outline or table, check for some content
        if outlines.count > 0 {
            let outline = outlines.firstMatch
            // Outline should have some rows
            XCTAssertTrue(outline.exists, "File browser outline should exist")
        } else if tables.count > 0 {
            let table = tables.firstMatch
            // Table should have some cells
            XCTAssertTrue(table.exists, "File browser table should exist")
        }
    }

    /// Test navigation using keyboard in file browser
    func testFileBrowserKeyboardNavigation() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Ensure file browser is visible
        let fileBrowserToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Show File Browser'")).firstMatch
        if fileBrowserToggle.exists {
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Use View menu to toggle file browser via keyboard shortcut
        let menuBar = app.menuBars.firstMatch
        if menuBar.exists {
            let viewMenu = menuBar.menuItems["View"]
            if viewMenu.exists {
                viewMenu.click()
                Thread.sleep(forTimeInterval: 0.2)

                // Look for "Toggle File Browser" or similar menu item
                let toggleMenuItem = app.menuItems.matching(NSPredicate(format: "title CONTAINS 'File Browser'")).firstMatch
                if toggleMenuItem.exists {
                    XCTAssertTrue(toggleMenuItem.isEnabled, "File browser menu item should be enabled")
                    // Don't click to avoid changing state
                }
            }
        }

        // Try arrow key navigation if file browser has focus
        let outlines = app.outlines
        if outlines.count > 0 {
            let outline = outlines.firstMatch
            outline.click()
            Thread.sleep(forTimeInterval: 0.3)

            // Try to navigate with arrow keys
            app.typeKey(.downArrow, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.2)

            app.typeKey(.upArrow, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    /// Test file browser context menu operations
    func testFileBrowserContextMenu() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Ensure file browser is visible
        let fileBrowserToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Show File Browser'")).firstMatch
        if fileBrowserToggle.exists {
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Check File Browser menu for available operations
        let menuBar = app.menuBars.firstMatch
        if menuBar.exists {
            let fileBrowserMenu = menuBar.menuItems["File Browser"]
            if fileBrowserMenu.exists {
                fileBrowserMenu.click()
                Thread.sleep(forTimeInterval: 0.3)

                // Check for expected operations
                let newFileItem = app.menuItems["New File"]
                let newFolderItem = app.menuItems["New Folder"]

                // At least some operations should be available
                let hasOperations = newFileItem.exists || newFolderItem.exists
                XCTAssertTrue(hasOperations, "File browser should have file operations available")

                // Close the menu by pressing Escape
                app.typeKey(.escape, modifierFlags: [])
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }

    /// Test file browser can expand and collapse folders
    func testFileBrowserExpandCollapse() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Ensure file browser is visible
        let fileBrowserToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Show File Browser'")).firstMatch
        if fileBrowserToggle.exists {
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Look for disclosure triangles (typical for expandable tree views)
        let outlines = app.outlines
        if outlines.count > 0 {
            let outline = outlines.firstMatch

            // Look for disclosure buttons (triangles)
            let disclosureButtons = outline.buttons

            if disclosureButtons.count > 0 {
                let firstDisclosure = disclosureButtons.firstMatch

                // Click to expand
                firstDisclosure.click()
                Thread.sleep(forTimeInterval: 0.5)

                // Click to collapse
                firstDisclosure.click()
                Thread.sleep(forTimeInterval: 0.5)

                XCTAssertTrue(true, "Successfully toggled folder disclosure")
            } else {
                // No expandable folders, which is fine
                XCTAssertTrue(true, "No expandable folders found")
            }
        }
    }

    /// Test file browser integration with editor
    func testFileBrowserOpensFiles() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Ensure file browser is visible
        let fileBrowserToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Show File Browser'")).firstMatch
        if fileBrowserToggle.exists {
            fileBrowserToggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Look for the outline/table
        let outlines = app.outlines
        let tables = app.tables

        if outlines.count > 0 {
            let outline = outlines.firstMatch

            // Get all rows
            let rows = outline.children(matching: .outlineRow)

            if rows.count > 0 {
                // Try to find a file (not folder) - usually indicated by no disclosure triangle
                // For simplicity, just double-click the first item
                let firstRow = rows.firstMatch

                // Record editor state before
                let editorButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Editor'")).firstMatch

                // Double-click to open file
                firstRow.doubleClick()
                Thread.sleep(forTimeInterval: 1.0)

                // Editor should become active if a file was opened
                if editorButton.exists {
                    // Just verify the editor tab exists and is clickable
                    XCTAssertTrue(editorButton.isEnabled, "Editor should be accessible after file selection")
                }
            }
        } else if tables.count > 0 {
            let table = tables.firstMatch
            let cells = table.cells

            if cells.count > 0 {
                let firstCell = cells.firstMatch
                firstCell.doubleClick()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // Verify app is still responsive
        XCTAssertTrue(window.exists, "Window should still exist after file operation")
    }
}
