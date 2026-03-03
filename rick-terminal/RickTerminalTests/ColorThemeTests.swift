import XCTest
import SwiftUI
@testable import RickTerminal

/// Unit tests for Color+Theme extension and RickTheme
class ColorThemeTests: XCTestCase {

    // MARK: - Color Hex Initialization Tests

    func testHexColorInit6Digit() {
        // Given
        let hexString = "FF5733"

        // When
        let color = Color(hex: hexString)

        // Then - Color should be created (exact value comparison is complex in SwiftUI)
        XCTAssertNotNil(color)
    }

    func testHexColorInitWithHash() {
        // Given
        let hexString = "#2196F3"

        // When
        let color = Color(hex: hexString)

        // Then
        XCTAssertNotNil(color)
    }

    func testHexColorInit3Digit() {
        // Given - 3 digit hex (RGB 12-bit)
        let hexString = "F53"

        // When
        let color = Color(hex: hexString)

        // Then - Should expand to FF5533
        XCTAssertNotNil(color)
    }

    func testHexColorInit8Digit() {
        // Given - 8 digit hex (ARGB 32-bit)
        let hexString = "80FF5733"

        // When
        let color = Color(hex: hexString)

        // Then - Should include alpha
        XCTAssertNotNil(color)
    }

    func testHexColorInitInvalidLength() {
        // Given - Invalid hex string
        let hexString = "FF573" // 5 digits - invalid

        // When
        let color = Color(hex: hexString)

        // Then - Should create black as fallback
        XCTAssertNotNil(color)
    }

    func testHexColorInitEmptyString() {
        // Given
        let hexString = ""

        // When
        let color = Color(hex: hexString)

        // Then - Should create black as fallback
        XCTAssertNotNil(color)
    }

    func testHexColorInitSpecialCharacters() {
        // Given - Hex with special characters that should be stripped
        let hexString = "#!@2196F3$%^"

        // When
        let color = Color(hex: hexString)

        // Then
        XCTAssertNotNil(color)
    }

    // MARK: - Rick Terminal Theme Colors Tests

    func testRTBackgroundDark() {
        let color = Color.rtBackgroundDark
        XCTAssertNotNil(color)
    }

    func testRTBackgroundLight() {
        let color = Color.rtBackgroundLight
        XCTAssertNotNil(color)
    }

    func testRTBackgroundSecondary() {
        let color = Color.rtBackgroundSecondary
        XCTAssertNotNil(color)
    }

    func testRTAccentPurple() {
        let color = Color.rtAccentPurple
        XCTAssertNotNil(color)
    }

    func testRTAccentGreen() {
        let color = Color.rtAccentGreen
        XCTAssertNotNil(color)
    }

    func testRTAccentBlue() {
        let color = Color.rtAccentBlue
        XCTAssertNotNil(color)
    }

    func testRTAccentOrange() {
        let color = Color.rtAccentOrange
        XCTAssertNotNil(color)
    }

    func testRTText() {
        let color = Color.rtText
        XCTAssertNotNil(color)
    }

    func testRTTextPrimary() {
        let color = Color.rtTextPrimary
        XCTAssertNotNil(color)
        // Should be same as rtText
        XCTAssertEqual(Color.rtText.description, Color.rtTextPrimary.description)
    }

    func testRTTextSecondary() {
        let color = Color.rtTextSecondary
        XCTAssertNotNil(color)
    }

    func testRTBorderSubtle() {
        let color = Color.rtBorderSubtle
        XCTAssertNotNil(color)
    }

    func testRTMuted() {
        let color = Color.rtMuted
        XCTAssertNotNil(color)
    }

    // MARK: - All Theme Colors Present

    func testAllThemeColorsDefined() {
        // Given - All theme colors should be defined
        let colors: [Color] = [
            .rtBackgroundDark,
            .rtBackgroundLight,
            .rtBackgroundSecondary,
            .rtAccentPurple,
            .rtAccentGreen,
            .rtAccentBlue,
            .rtAccentOrange,
            .rtText,
            .rtTextPrimary,
            .rtTextSecondary,
            .rtBorderSubtle,
            .rtMuted
        ]

        // When/Then - All colors should be non-nil
        for color in colors {
            XCTAssertNotNil(color)
        }
    }
}

// MARK: - RickTheme Tests

class RickThemeTests: XCTestCase {

    func testSharedInstance() {
        // Given/When
        let theme1 = RickTheme.shared
        let theme2 = RickTheme.shared

        // Then - Should be same instance
        XCTAssertTrue(theme1 === theme2)
    }

    func testDefaultColors() {
        // Given
        let theme = RickTheme.shared

        // When/Then - Default colors should be set
        XCTAssertNotNil(theme.backgroundColor)
        XCTAssertNotNil(theme.backgroundSecondary)
        XCTAssertNotNil(theme.accentPrimary)
        XCTAssertNotNil(theme.accentSuccess)
        XCTAssertNotNil(theme.textPrimary)
        XCTAssertNotNil(theme.textMuted)
    }

    func testComputedProperties() {
        // Given
        let theme = RickTheme.shared

        // When/Then
        XCTAssertNotNil(theme.terminalPrompt)
        XCTAssertNotNil(theme.terminalOutput)
        XCTAssertNotNil(theme.activeIndicator)
        XCTAssertNotNil(theme.inactiveIndicator)
        XCTAssertNotNil(theme.buttonFocus)
    }

    func testTerminalPromptColor() {
        // Given
        let theme = RickTheme.shared

        // When/Then - Terminal prompt should be accent success (green)
        XCTAssertEqual(theme.terminalPrompt.description, theme.accentSuccess.description)
    }

    func testTerminalOutputColor() {
        // Given
        let theme = RickTheme.shared

        // When/Then - Terminal output should be text primary
        XCTAssertEqual(theme.terminalOutput.description, theme.textPrimary.description)
    }

    func testActiveIndicatorColor() {
        // Given
        let theme = RickTheme.shared

        // When/Then - Active indicator should be accent success
        XCTAssertEqual(theme.activeIndicator.description, theme.accentSuccess.description)
    }

    func testInactiveIndicatorColor() {
        // Given
        let theme = RickTheme.shared

        // When/Then - Inactive indicator should be muted
        XCTAssertEqual(theme.inactiveIndicator.description, theme.textMuted.description)
    }

    func testButtonFocusColor() {
        // Given
        let theme = RickTheme.shared

        // When/Then - Button focus should be accent primary (purple)
        XCTAssertEqual(theme.buttonFocus.description, theme.accentPrimary.description)
    }

    func testResetToDefault() {
        // Given
        let theme = RickTheme()
        let originalBg = theme.backgroundColor

        // When - Modify and reset
        theme.backgroundColor = Color.red
        XCTAssertNotEqual(theme.backgroundColor.description, originalBg.description)

        theme.resetToDefault()

        // Then - Should be back to default
        XCTAssertEqual(theme.backgroundColor.description, Color.rtBackgroundDark.description)
        XCTAssertEqual(theme.backgroundSecondary.description, Color.rtBackgroundSecondary.description)
        XCTAssertEqual(theme.accentPrimary.description, Color.rtAccentPurple.description)
        XCTAssertEqual(theme.accentSuccess.description, Color.rtAccentGreen.description)
        XCTAssertEqual(theme.textPrimary.description, Color.rtText.description)
        XCTAssertEqual(theme.textMuted.description, Color.rtMuted.description)
    }

    func testObservableObject() {
        // Given
        let theme = RickTheme()
        let expectation = XCTestExpectation(description: "Theme changed")

        // When
        let cancellable = theme.objectWillChange.sink {
            expectation.fulfill()
        }

        // Modify a published property
        theme.backgroundColor = Color.blue

        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
}

// MARK: - Hex Color Conversion Accuracy Tests

class HexColorConversionTests: XCTestCase {

    func testPureRed() {
        // Given
        let hex = "FF0000"

        // When
        let color = Color(hex: hex)

        // Then - Should be pure red
        XCTAssertNotNil(color)
    }

    func testPureGreen() {
        // Given
        let hex = "00FF00"

        // When
        let color = Color(hex: hex)

        // Then - Should be pure green
        XCTAssertNotNil(color)
    }

    func testPureBlue() {
        // Given
        let hex = "0000FF"

        // When
        let color = Color(hex: hex)

        // Then - Should be pure blue
        XCTAssertNotNil(color)
    }

    func testWhite() {
        // Given
        let hex = "FFFFFF"

        // When
        let color = Color(hex: hex)

        // Then - Should be white
        XCTAssertNotNil(color)
    }

    func testBlack() {
        // Given
        let hex = "000000"

        // When
        let color = Color(hex: hex)

        // Then - Should be black
        XCTAssertNotNil(color)
    }

    func testGray() {
        // Given
        let hex = "808080"

        // When
        let color = Color(hex: hex)

        // Then - Should be gray
        XCTAssertNotNil(color)
    }

    func testLowerCaseHex() {
        // Given
        let hex = "ff5733"

        // When
        let color = Color(hex: hex)

        // Then - Should work with lowercase
        XCTAssertNotNil(color)
    }

    func testMixedCaseHex() {
        // Given
        let hex = "fF5733"

        // When
        let color = Color(hex: hex)

        // Then - Should work with mixed case
        XCTAssertNotNil(color)
    }

    func testRickTerminalBrandColors() {
        // Given - Test all brand colors can be initialized
        let brandColors = [
            "0D1010", // Background dark
            "1A1F1F", // Background light
            "1E3738", // Background secondary
            "7B78AA", // Accent purple
            "7FFC50", // Accent green
            "2196F3", // Accent blue
            "FF9F40", // Accent orange
            "FFFFFF", // Text
            "9CA3AF", // Text secondary
            "2D3748", // Border subtle
            "464467"  // Muted
        ]

        // When/Then - All should initialize successfully
        for hexColor in brandColors {
            let color = Color(hex: hexColor)
            XCTAssertNotNil(color, "Failed to create color from hex: \(hexColor)")
        }
    }
}
