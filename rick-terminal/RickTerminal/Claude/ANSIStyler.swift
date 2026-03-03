import Foundation
import AppKit

/// Applies ANSI escape codes to add terminal styling
/// Used to visually distinguish Claude output in the terminal
final class ANSIStyler {

    // MARK: - ANSI Color Codes

    enum Color: String {
        // Basic colors
        case black = "30"
        case red = "31"
        case green = "32"
        case yellow = "33"
        case blue = "34"
        case magenta = "35"
        case cyan = "36"
        case white = "37"

        // Bright colors
        case brightBlack = "90"
        case brightRed = "91"
        case brightGreen = "92"
        case brightYellow = "93"
        case brightBlue = "94"
        case brightMagenta = "95"
        case brightCyan = "96"
        case brightWhite = "97"

        // RGB color (256-color mode)
        static func rgb(_ r: Int, _ g: Int, _ b: Int) -> String {
            return "38;2;\(r);\(g);\(b)"
        }

        // Background RGB color
        static func rgbBg(_ r: Int, _ g: Int, _ b: Int) -> String {
            return "48;2;\(r);\(g);\(b)"
        }
    }

    enum Style: String {
        case reset = "0"
        case bold = "1"
        case dim = "2"
        case italic = "3"
        case underline = "4"
        case blink = "5"
        case reverse = "7"
        case hidden = "8"
        case strikethrough = "9"
    }

    // MARK: - Rick Terminal Colors (RGB)

    static let rtPurple = (r: 123, g: 120, b: 170)      // #7B78AA
    static let rtGreen = (r: 127, g: 252, b: 80)        // #7FFC50
    static let rtOrange = (r: 255, g: 159, b: 64)       // #FF9F40
    static let rtBackgroundSecondary = (r: 30, g: 55, b: 56) // #1E3738
    static let rtMuted = (r: 70, g: 68, b: 103)         // #464467

    // MARK: - Styling Methods

    /// Wrap text with ANSI color codes
    static func color(_ text: String, fg: Color? = nil, bg: Color? = nil) -> String {
        var codes: [String] = []

        if let fg = fg {
            codes.append(fg.rawValue)
        }

        if let bg = bg {
            codes.append("4" + bg.rawValue)
        }

        if codes.isEmpty {
            return text
        }

        return "\u{001B}[\(codes.joined(separator: ";"))m\(text)\u{001B}[0m"
    }

    /// Wrap text with RGB color
    static func colorRGB(_ text: String, r: Int, g: Int, b: Int) -> String {
        return "\u{001B}[\(Color.rgb(r, g, b))m\(text)\u{001B}[0m"
    }

    /// Wrap text with RGB background color
    static func backgroundRGB(_ text: String, r: Int, g: Int, b: Int) -> String {
        return "\u{001B}[\(Color.rgbBg(r, g, b))m\(text)\u{001B}[0m"
    }

    /// Apply style to text
    static func style(_ text: String, _ style: Style) -> String {
        return "\u{001B}[\(style.rawValue)m\(text)\u{001B}[0m"
    }

    /// Combine multiple styles and colors
    static func styled(_ text: String, styles: [Style] = [], fg: Color? = nil, bg: Color? = nil) -> String {
        var codes: [String] = []

        codes.append(contentsOf: styles.map { $0.rawValue })

        if let fg = fg {
            codes.append(fg.rawValue)
        }

        if let bg = bg {
            codes.append("4" + bg.rawValue)
        }

        if codes.isEmpty {
            return text
        }

        return "\u{001B}[\(codes.joined(separator: ";"))m\(text)\u{001B}[0m"
    }

    // MARK: - Claude-Specific Styling

    /// Style text as a Claude response (purple left border effect)
    static func claudeResponse(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let styledLines = lines.map { line -> String in
            let border = colorRGB("▎", r: rtPurple.r, g: rtPurple.g, b: rtPurple.b)
            return "\(border) \(line)"
        }
        return styledLines.joined(separator: "\n")
    }

    /// Style code block with syntax highlighting
    static func codeBlock(_ code: String, language: String? = nil) -> String {
        var result = ""

        // Detect language from hint
        let detectedLang = language.flatMap { SyntaxLanguage(rawValue: $0.lowercased()) }

        // Use SyntaxHighlightingService for proper highlighting
        let highlightResult = SyntaxHighlightingService.shared.highlightSync(
            code,
            language: detectedLang,
            filename: nil
        )

        // Add language label with indicator
        let langDisplay = highlightResult.language.displayName
        let indicator = highlightResult.usedFallback ? "⚡" : "✓"
        result += colorRGB("\(indicator) [\(langDisplay)]", r: rtMuted.r, g: rtMuted.g, b: rtMuted.b) + "\n"

        // Use the ANSI string from the service
        result += highlightResult.ansiString

        return result
    }

    /// Style inline code (short snippets without language detection)
    static func inlineCode(_ code: String) -> String {
        // For inline code, use simple green color without heavy highlighting
        // Inline code is typically too short for meaningful syntax highlighting
        return colorRGB(code, r: rtGreen.r, g: rtGreen.g, b: rtGreen.b)
    }

    /// Style header
    static func header(_ text: String, level: Int = 1) -> String {
        return styled(text, styles: [.bold], fg: nil) + " " +
               colorRGB("", r: rtPurple.r, g: rtPurple.g, b: rtPurple.b)
    }

    /// Style tool invocation
    static func toolInvocation(_ text: String) -> String {
        return colorRGB(text, r: rtPurple.r, g: rtPurple.g, b: rtPurple.b)
    }

    /// Style error message
    static func error(_ text: String) -> String {
        return colorRGB(text, r: rtOrange.r, g: rtOrange.g, b: rtOrange.b)
    }

    /// Style thinking block (dimmed/italic)
    static func thinking(_ text: String) -> String {
        return styled(text, styles: [.dim, .italic])
    }

    // MARK: - Markdown Styling (Terminal-friendly)

    /// Apply basic markdown styling using ANSI codes
    static func markdown(_ text: String) -> String {
        var result = text

        // Headers (## Header -> bold + purple)
        result = result.replacingOccurrences(
            of: #"^(#{1,6})\s+(.+)$"#,
            with: "\u{001B}[1m\u{001B}[\(Color.rgb(rtPurple.r, rtPurple.g, rtPurple.b))m$2\u{001B}[0m",
            options: .regularExpression
        )

        // Bold (**text** or __text__)
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "\u{001B}[1m$1\u{001B}[0m",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#,
            with: "\u{001B}[1m$1\u{001B}[0m",
            options: .regularExpression
        )

        // Italic (*text* or _text_)
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
            with: "\u{001B}[3m$1\u{001B}[0m",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#,
            with: "\u{001B}[3m$1\u{001B}[0m",
            options: .regularExpression
        )

        // Inline code (`code`)
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "\u{001B}[\(Color.rgb(rtGreen.r, rtGreen.g, rtGreen.b))m$1\u{001B}[0m",
            options: .regularExpression
        )

        // List items
        result = result.replacingOccurrences(
            of: #"^(\s*)[•\-\*]\s+"#,
            with: "$1\u{001B}[\(Color.rgb(rtGreen.r, rtGreen.g, rtGreen.b))m•\u{001B}[0m ",
            options: .regularExpression
        )

        return result
    }

    // MARK: - Utilities

    /// Strip all ANSI codes from text (for length calculation, etc.)
    static func strip(_ text: String) -> String {
        let pattern = "\u{001B}\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    /// Get visible length of text (excluding ANSI codes)
    static func visibleLength(_ text: String) -> Int {
        return strip(text).count
    }
}

// MARK: - String Extension

extension String {
    /// Apply ANSI color
    func ansiForeground(_ color: ANSIStyler.Color) -> String {
        return ANSIStyler.color(self, fg: color)
    }

    /// Apply ANSI style
    func ansiStyle(_ style: ANSIStyler.Style) -> String {
        return ANSIStyler.style(self, style)
    }

    /// Style as Claude response
    func asClaudeResponse() -> String {
        return ANSIStyler.claudeResponse(self)
    }

    /// Style as code block
    func asCodeBlock(language: String? = nil) -> String {
        return ANSIStyler.codeBlock(self, language: language)
    }

    /// Apply markdown styling
    func markdownStyled() -> String {
        return ANSIStyler.markdown(self)
    }
}
