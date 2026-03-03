import SwiftUI
import AppKit

/// Terminal appearance and behavior settings
/// Manages font, colors, cursor style, and keyboard shortcuts
class TerminalSettings: ObservableObject {
    static let shared = TerminalSettings()

    // MARK: - Font Settings

    /// Terminal font size (stored in UserDefaults)
    @AppStorage("terminalFontSize") var fontSize: Double = 13.0

    /// Minimum font size
    static let minFontSize: Double = 8.0

    /// Maximum font size
    static let maxFontSize: Double = 36.0

    /// Font size increment for zoom operations
    static let fontSizeIncrement: Double = 1.0

    /// Preferred monospace font (SF Mono or fallback to Menlo)
    var terminalFont: NSFont {
        // Try SF Mono first (macOS system monospace font)
        if let sfMono = NSFont(name: "SFMono-Regular", size: fontSize) {
            return sfMono
        }
        // Fallback to Menlo if SF Mono unavailable
        if let menlo = NSFont(name: "Menlo-Regular", size: fontSize) {
            return menlo
        }
        // Final fallback to system monospace
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    // MARK: - Color Settings

    /// Terminal background color
    var backgroundColor: NSColor {
        NSColor(Color.rtBackgroundDark)
    }

    /// Terminal foreground (text) color
    var foregroundColor: NSColor {
        NSColor(Color.rtText)
    }

    /// Cursor color
    var cursorColor: NSColor {
        NSColor(Color.rtAccentGreen)
    }

    /// Selection background color
    var selectionBackgroundColor: NSColor {
        NSColor(Color.rtAccentPurple.opacity(0.3))
    }

    // MARK: - ANSI Color Palette

    /// ANSI color palette matching Rick Terminal theme
    /// Indices: 0-7 normal colors, 8-15 bright colors
    var ansiColors: [NSColor] {
        [
            // Normal colors (0-7)
            NSColor(Color(hex: "0D1010")),      // Black (background)
            NSColor(Color(hex: "FF6B6B")),      // Red
            NSColor(Color(hex: "7FFC50")),      // Green (accent)
            NSColor(Color(hex: "FFD93D")),      // Yellow
            NSColor(Color(hex: "6BCF7F")),      // Blue
            NSColor(Color(hex: "7B78AA")),      // Magenta (purple accent)
            NSColor(Color(hex: "4ECDC4")),      // Cyan
            NSColor(Color(hex: "FFFFFF")),      // White (foreground)

            // Bright colors (8-15)
            NSColor(Color(hex: "464467")),      // Bright Black (muted)
            NSColor(Color(hex: "FF8787")),      // Bright Red
            NSColor(Color(hex: "A0FF7F")),      // Bright Green
            NSColor(Color(hex: "FFE066")),      // Bright Yellow
            NSColor(Color(hex: "87E0A0")),      // Bright Blue
            NSColor(Color(hex: "9B98CA")),      // Bright Magenta
            NSColor(Color(hex: "6EEEE4")),      // Bright Cyan
            NSColor(Color(hex: "FFFFFF"))       // Bright White
        ]
    }

    // MARK: - Cursor Settings

    /// Cursor style (block, underline, bar)
    @AppStorage("cursorStyle") private var _cursorStyle: String = "block"

    var cursorStyle: CursorStyle {
        get { CursorStyle(rawValue: _cursorStyle) ?? .block }
        set { _cursorStyle = newValue.rawValue }
    }

    enum CursorStyle: String, CaseIterable {
        case block = "block"
        case underline = "underline"
        case bar = "bar"

        var displayName: String {
            switch self {
            case .block: return "Block"
            case .underline: return "Underline"
            case .bar: return "Bar"
            }
        }
    }

    /// Cursor blink enabled
    @AppStorage("cursorBlink") var cursorBlink: Bool = true

    // MARK: - Claude CLI Settings

    /// Path to Claude CLI executable
    @AppStorage("claudeCliPath") var claudeCliPath: String = ""

    /// Whether Claude CLI path has been auto-detected
    @AppStorage("claudeCliAutoDetected") private var claudeCliAutoDetected: Bool = false

    /// Get the Claude CLI path, auto-detecting on first access if needed
    func getClaudeCliPath() -> String? {
        // If we already have a valid path, return it
        if !claudeCliPath.isEmpty {
            return claudeCliPath
        }

        // Hardcoded fallback paths - check file existence directly
        let fallbackPaths = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/opt/local/bin/claude"
        ]

        let fileManager = FileManager.default
        for path in fallbackPaths {
            if fileManager.fileExists(atPath: path) {
                claudeCliPath = path
                claudeCliAutoDetected = true
                print("[ClaudePathDetector] Found Claude at: \(path)")
                return path
            }
        }

        // Try auto-detection as last resort
        if let detectedPath = ClaudePathDetector.shared.autoDetect() {
            claudeCliPath = detectedPath
            claudeCliAutoDetected = true
            return detectedPath
        }

        print("[ClaudePathDetector] Claude CLI not found!")
        return nil
    }

    /// Validate and set Claude CLI path
    /// - Parameter path: Path to set
    /// - Returns: true if path is valid and was set, false otherwise
    @discardableResult
    func setClaudeCliPath(_ path: String) -> Bool {
        let expandedPath = ClaudePathDetector.shared.expandPath(path)

        if ClaudePathDetector.shared.isValidClaudePath(expandedPath) {
            claudeCliPath = expandedPath
            return true
        }

        return false
    }

    /// Reset Claude CLI detection (for re-detection)
    func resetClaudeCliDetection() {
        claudeCliAutoDetected = false
        claudeCliPath = ""
    }

    // MARK: - Claude Auto-Launch Settings

    /// Whether Claude CLI should auto-launch on terminal start
    @AppStorage("claudeAutoLaunch") var claudeAutoLaunch: Bool = false

    /// Whether to show a prompt before auto-launching Claude
    @AppStorage("claudeAutoLaunchPrompt") var claudeAutoLaunchPrompt: Bool = true

    // MARK: - Font Size Actions

    /// Increase font size (Cmd+)
    func increaseFontSize() {
        let newSize = min(fontSize + Self.fontSizeIncrement, Self.maxFontSize)
        fontSize = newSize
    }

    /// Decrease font size (Cmd-)
    func decreaseFontSize() {
        let newSize = max(fontSize - Self.fontSizeIncrement, Self.minFontSize)
        fontSize = newSize
    }

    /// Reset font size to default
    func resetFontSize() {
        fontSize = 13.0
    }

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton pattern
    }
}

// MARK: - Environment Key

private struct TerminalSettingsKey: EnvironmentKey {
    static let defaultValue = TerminalSettings.shared
}

extension EnvironmentValues {
    var terminalSettings: TerminalSettings {
        get { self[TerminalSettingsKey.self] }
        set { self[TerminalSettingsKey.self] = newValue }
    }
}

extension View {
    /// Inject terminal settings into view hierarchy
    func terminalSettings(_ settings: TerminalSettings = .shared) -> some View {
        self.environment(\.terminalSettings, settings)
            .environmentObject(settings)
    }
}
