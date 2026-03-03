import SwiftUI

extension Color {
    // MARK: - Rick Terminal Theme Colors

    /// Background dark - #0D1010
    static let rtBackgroundDark = Color(hex: "0D1010")

    /// Background light - #1A1F1F
    static let rtBackgroundLight = Color(hex: "1A1F1F")

    /// Background secondary - #1E3738
    static let rtBackgroundSecondary = Color(hex: "1E3738")

    /// Accent purple - #7B78AA
    static let rtAccentPurple = Color(hex: "7B78AA")

    /// Accent green/success - #7FFC50
    static let rtAccentGreen = Color(hex: "7FFC50")

    /// Accent blue - #2196F3
    static let rtAccentBlue = Color(hex: "2196F3")

    /// Accent orange/warning - #FF9F40
    static let rtAccentOrange = Color(hex: "FF9F40")

    /// Text primary - #FFFFFF
    static let rtText = Color(hex: "FFFFFF")
    static let rtTextPrimary = Color(hex: "FFFFFF")

    /// Text secondary - #9CA3AF
    static let rtTextSecondary = Color(hex: "9CA3AF")

    /// Text disabled - #6B7280
    static let rtTextDisabled = Color(hex: "6B7280")

    /// Border subtle - #2D3748
    static let rtBorderSubtle = Color(hex: "2D3748")

    /// Muted - #464467
    static let rtMuted = Color(hex: "464467")

    // MARK: - Convenience Initializer

    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (with or without #)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
