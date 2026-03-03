import SwiftUI

/// Rick Terminal theme configuration
/// Provides centralized theming for the entire application
class RickTheme: ObservableObject {
    static let shared = RickTheme()

    // MARK: - Theme Properties

    /// Primary background color
    @Published var backgroundColor: Color = .rtBackgroundDark

    /// Secondary background color (for panels, tabs, etc.)
    @Published var backgroundSecondary: Color = .rtBackgroundSecondary

    /// Primary accent color (purple)
    @Published var accentPrimary: Color = .rtAccentPurple

    /// Success/active accent color (green)
    @Published var accentSuccess: Color = .rtAccentGreen

    /// Primary text color
    @Published var textPrimary: Color = .rtText

    /// Muted/disabled text color
    @Published var textMuted: Color = .rtMuted

    // MARK: - Computed Properties

    /// Terminal prompt color
    var terminalPrompt: Color { accentSuccess }

    /// Terminal output color
    var terminalOutput: Color { textPrimary }

    /// Active session indicator
    var activeIndicator: Color { accentSuccess }

    /// Inactive session indicator
    var inactiveIndicator: Color { textMuted }

    /// Button hover/focus color
    var buttonFocus: Color { accentPrimary }

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton pattern
        // Dark mode is default and only mode
    }

    // MARK: - Theme Methods

    /// Reset theme to default values
    func resetToDefault() {
        backgroundColor = .rtBackgroundDark
        backgroundSecondary = .rtBackgroundSecondary
        accentPrimary = .rtAccentPurple
        accentSuccess = .rtAccentGreen
        textPrimary = .rtText
        textMuted = .rtMuted
    }
}

// MARK: - Environment Key

private struct RickThemeKey: EnvironmentKey {
    static let defaultValue = RickTheme.shared
}

extension EnvironmentValues {
    var rickTheme: RickTheme {
        get { self[RickThemeKey.self] }
        set { self[RickThemeKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Apply Rick Terminal theme to view hierarchy
    func rickTheme(_ theme: RickTheme = .shared) -> some View {
        self.environment(\.rickTheme, theme)
            .environmentObject(theme)
    }
}
