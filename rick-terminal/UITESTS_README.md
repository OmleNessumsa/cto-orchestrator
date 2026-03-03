# Rick Terminal UI Tests

## Overview
Comprehensive XCUITest suite for Rick Terminal covering critical user flows and smoke tests.

## Test Files Created

### 1. AppLaunchTests.swift
Tests app initialization and basic UI elements:
- App launches successfully
- Main UI elements are present (Terminal/Editor tabs, sidebar toggles)
- Window title is correct
- Panels can be collapsed and expanded

### 2. TerminalInteractionTests.swift
Tests terminal input/output functionality:
- Terminal exists and is accessible
- Terminal accepts keyboard input
- Clear terminal functionality
- Multi-line input handling
- Interrupt process (Ctrl+C) functionality

### 3. FileBrowserTests.swift
Tests file browser navigation:
- File browser can be toggled on/off
- File browser displays directory structure
- Keyboard navigation in file browser
- Context menu operations
- Folder expand/collapse
- File opening integration with editor

### 4. KanbanBoardTests.swift
Tests Kanban board interaction:
- Kanban board can be toggled
- Kanban columns are displayed
- Menu access to Kanban features
- Empty state handling
- Card interaction (clicking/selecting)
- Drag and drop functionality
- State persistence across toggles
- Keyboard shortcuts

## Test Target Setup

The UI test target `RickTerminalUITests` has been added to the Xcode project with:
- Target SDK: macOS 13.0+
- Test files properly configured
- Dependency on main RickTerminal app

## Running the Tests

### Via Xcode:
1. Open RickTerminal.xcodeproj
2. Select RickTerminalUITests scheme
3. Press Cmd+U to run all UI tests

### Via Command Line:
```bash
xcodebuild test -scheme RickTerminal -destination 'platform=macOS'
```

### Running Specific Tests:
```bash
# Run only app launch tests
xcodebuild test -scheme RickTerminal \
  -destination 'platform=macOS' \
  -only-testing:RickTerminalUITests/AppLaunchTests

# Run only terminal interaction tests
xcodebuild test -scheme RickTerminal \
  -destination 'platform=macOS' \
  -only-testing:RickTerminalUITests/TerminalInteractionTests
```

## Test Requirements

- macOS 13.0 or later
- Xcode 14.0 or later
- App must be built and installed for testing
- App must launch with `--uitesting` flag (automatically handled by XCTest)

## Test Design Principles

### 1. Non-Flaky Tests
- Proper wait conditions using `waitForExistence(timeout:)`
- Thread sleeps only where necessary for animations
- Predicates for robust element finding
- Fallback checks for optional UI elements

### 2. Resilient Element Finding
- Uses predicates (e.g., `label CONTAINS 'Terminal'`) instead of exact matches
- Checks for multiple possible element types (outlines, tables, scroll views)
- Handles cases where UI elements may not exist (optional features)

### 3. Smoke Test Coverage
- Tests cover critical happy paths
- Focus on detecting obvious regressions
- No deep functional testing (that's for unit tests)
- Tests verify app remains responsive after operations

### 4. UI Agnostic
- Tests don't depend on specific button positions or colors
- Uses accessibility labels and semantic queries
- Works with menu bar as fallback for button interactions

## Test Structure

Each test file follows this pattern:

```swift
final class TestSuite: XCTestCase {
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

    func testFeature() throws {
        // Test implementation
    }
}
```

## Known Limitations

1. **Drag and Drop**: XCUITest drag and drop can be unreliable with custom SwiftUI views. Tests verify the operation doesn't crash but may not verify exact position changes.

2. **Terminal Output Verification**: Tests verify terminal accepts input but don't parse/verify output text due to asynchronous nature and varying shell prompts.

3. **File Browser Content**: Tests verify file browser exists and has structure but don't verify specific files/folders as those vary by project.

4. **Timing**: Some tests use fixed `Thread.sleep()` intervals for animations. If tests are flaky, these timeouts may need adjustment.

## Maintenance

### Adding New Tests
1. Create new test method in appropriate test file
2. Follow existing pattern: wait for elements, interact, verify
3. Use `waitForExistence(timeout:)` instead of fixed sleeps when possible
4. Add descriptive test names: `testFeatureDoesX`

### Updating for UI Changes
1. If element finding fails, check predicates (e.g., label text changes)
2. Update `waitForExistence()` timeouts if app is slower
3. Add fallback element queries if UI structure changes

## Integration with CI/CD

To run these tests in CI:

```bash
# Build for testing
xcodebuild build-for-testing \
  -scheme RickTerminal \
  -destination 'platform=macOS'

# Run tests
xcodebuild test-without-building \
  -scheme RickTerminal \
  -destination 'platform=macOS' \
  -resultBundlePath TestResults.xcresult
```

## Troubleshooting

### Tests fail with "element not found"
- Increase timeout values in `waitForExistence(timeout:)`
- Check if UI structure has changed
- Verify app actually launches

### Tests are flaky
- Add more explicit waits
- Check for race conditions in app code
- Increase sleep intervals after UI operations

### App doesn't launch
- Verify app builds successfully
- Check that app target is signed
- Ensure test target has dependency on app target

## Next Steps

### Before Running Tests
The main RickTerminal app currently has compilation errors that need to be fixed:
- Missing Color.rtMutedPurple color definition
- ErrorPresentation needs Equatable conformance
- RTError switch statement needs to be exhaustive

### Once App Builds
1. Fix any remaining app compilation errors
2. Run full UI test suite: `xcodebuild test -scheme RickTerminal`
3. Fix any test failures related to actual UI changes
4. Add tests to CI/CD pipeline

### Future Enhancements
1. Add performance tests (app launch time, etc.)
2. Add screenshot capturing on test failures
3. Add tests for error scenarios and edge cases
4. Expand Kanban drag-and-drop tests once SwiftUI drag APIs stabilize
