import Foundation
import AppKit

/// Renders markdown text to NSAttributedString with syntax highlighting for code blocks
/// Supports: headers, bold, italic, code, code blocks, links, lists
final class MarkdownRenderer {

    // MARK: - Typography

    private let baseFont: NSFont
    private let baseFontSize: CGFloat
    private let codeFont: NSFont

    // MARK: - Colors

    private let textColor: NSColor
    private let headingColor: NSColor
    private let codeTextColor: NSColor
    private let codeBackgroundColor: NSColor
    private let linkColor: NSColor
    private let quoteColor: NSColor

    // MARK: - Initialization

    init(
        baseFontSize: CGFloat = 12,
        textColor: NSColor = .white,
        headingColor: NSColor = NSColor(red: 0.48, green: 0.47, blue: 0.67, alpha: 1.0), // rtAccentPurple
        codeTextColor: NSColor = NSColor(red: 0.5, green: 1.0, blue: 0.31, alpha: 1.0), // rtAccentGreen
        codeBackgroundColor: NSColor = NSColor(red: 0.12, green: 0.22, blue: 0.22, alpha: 0.4), // rtBackgroundSecondary with alpha
        linkColor: NSColor = NSColor(red: 0.5, green: 1.0, blue: 0.31, alpha: 1.0), // rtAccentGreen
        quoteColor: NSColor = NSColor(red: 0.27, green: 0.27, blue: 0.40, alpha: 1.0) // rtMuted
    ) {
        self.baseFontSize = baseFontSize
        self.baseFont = .monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
        self.codeFont = .monospacedSystemFont(ofSize: baseFontSize - 1, weight: .medium)

        self.textColor = textColor
        self.headingColor = headingColor
        self.codeTextColor = codeTextColor
        self.codeBackgroundColor = codeBackgroundColor
        self.linkColor = linkColor
        self.quoteColor = quoteColor
    }

    // MARK: - Public API

    /// Render markdown text to attributed string
    func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Split into lines and process
        let lines = markdown.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeBlockLanguage: String?
        var codeBlockBuffer: [String] = []
        var listLevel = 0

        for (index, line) in lines.enumerated() {
            // Handle code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block - render accumulated code
                    let code = codeBlockBuffer.joined(separator: "\n")
                    let styledCode = renderCodeBlock(code, language: codeBlockLanguage)
                    result.append(styledCode)
                    result.append(NSAttributedString(string: "\n"))

                    codeBlockBuffer = []
                    codeBlockLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if codeBlockLanguage?.isEmpty == true {
                        codeBlockLanguage = nil
                    }
                }
                continue
            }

            if inCodeBlock {
                codeBlockBuffer.append(line)
                continue
            }

            // Process regular markdown line
            let styledLine = renderLine(line, listLevel: &listLevel)
            result.append(styledLine)

            // Add newline except for last line
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        // Handle unclosed code block
        if inCodeBlock && !codeBlockBuffer.isEmpty {
            let code = codeBlockBuffer.joined(separator: "\n")
            let styledCode = renderCodeBlock(code, language: codeBlockLanguage)
            result.append(styledCode)
        }

        return result
    }

    // MARK: - Line Rendering

    private func renderLine(_ line: String, listLevel: inout Int) -> NSAttributedString {
        // Headers
        if line.hasPrefix("#") {
            return renderHeader(line)
        }

        // Lists
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return renderListItem(line, level: 0)
        }

        // Ordered lists
        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return renderListItem(line, level: 0, ordered: true)
        }

        // Blockquotes
        if line.hasPrefix("> ") {
            return renderBlockquote(line)
        }

        // Regular text with inline formatting
        return renderInlineFormatting(line)
    }

    // MARK: - Header Rendering

    private func renderHeader(_ line: String) -> NSAttributedString {
        var level = 0
        var text = line

        while text.hasPrefix("#") {
            level += 1
            text = String(text.dropFirst())
        }

        text = text.trimmingCharacters(in: .whitespaces)

        let fontSize = baseFontSize + CGFloat(4 - level)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: headingColor
        ]

        return NSAttributedString(string: text, attributes: attrs)
    }

    // MARK: - List Rendering

    private func renderListItem(_ line: String, level: Int, ordered: Bool = false) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Add indent
        let indent = String(repeating: "  ", count: level)
        result.append(NSAttributedString(string: indent, attributes: baseAttributes()))

        // Extract marker and text
        var text = line
        if ordered {
            if let match = text.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                text = String(text[match.upperBound...])
            }
            result.append(NSAttributedString(string: "• ", attributes: [
                .foregroundColor: linkColor,
                .font: baseFont
            ]))
        } else {
            text = String(text.dropFirst(2)) // Remove "- " or "* "
            result.append(NSAttributedString(string: "• ", attributes: [
                .foregroundColor: linkColor,
                .font: baseFont
            ]))
        }

        // Render text with inline formatting
        result.append(renderInlineFormatting(text))

        return result
    }

    // MARK: - Blockquote Rendering

    private func renderBlockquote(_ line: String) -> NSAttributedString {
        let text = String(line.dropFirst(2)) // Remove "> "

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "│ ", attributes: [
            .foregroundColor: quoteColor,
            .font: baseFont
        ]))

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: quoteColor
        ]

        result.append(NSAttributedString(string: text, attributes: textAttrs))

        return result
    }

    // MARK: - Inline Formatting

    private func renderInlineFormatting(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes())

        // Apply bold (**text** or __text__)
        applyPattern(to: result, pattern: #"\*\*(.+?)\*\*"#, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .bold)
        ])

        applyPattern(to: result, pattern: #"__(.+?)__"#, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .bold)
        ])

        // Apply italic (*text* or _text_)
        applyPattern(to: result, pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .light),
            .obliqueness: 0.15
        ])

        applyPattern(to: result, pattern: #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .light),
            .obliqueness: 0.15
        ])

        // Apply inline code (`code`)
        applyInlineCode(to: result)

        // Apply links [text](url)
        applyLinks(to: result)

        return result
    }

    private func applyPattern(to attributedString: NSMutableAttributedString, pattern: String, attributes: [NSAttributedString.Key: Any]) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let string = attributedString.string
        let range = NSRange(location: 0, length: string.utf16.count)

        // Find all matches in reverse to avoid index shifting
        let matches = regex.matches(in: string, options: [], range: range).reversed()

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }

            let fullRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            // Extract content text
            guard let contentStringRange = Range(contentRange, in: string) else { continue }
            let content = String(string[contentStringRange])

            // Replace with styled content
            let replacement = NSAttributedString(string: content, attributes: attributes)
            attributedString.replaceCharacters(in: fullRange, with: replacement)
        }
    }

    private func applyInlineCode(to attributedString: NSMutableAttributedString) {
        let pattern = #"`([^`]+)`"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let string = attributedString.string
        let range = NSRange(location: 0, length: string.utf16.count)

        let matches = regex.matches(in: string, options: [], range: range).reversed()

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }

            let fullRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            guard let contentStringRange = Range(contentRange, in: string) else { continue }
            let content = String(string[contentStringRange])

            let attrs: [NSAttributedString.Key: Any] = [
                .font: codeFont,
                .foregroundColor: codeTextColor,
                .backgroundColor: codeBackgroundColor
            ]

            let replacement = NSAttributedString(string: content, attributes: attrs)
            attributedString.replaceCharacters(in: fullRange, with: replacement)
        }
    }

    private func applyLinks(to attributedString: NSMutableAttributedString) {
        let pattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let string = attributedString.string
        let range = NSRange(location: 0, length: string.utf16.count)

        let matches = regex.matches(in: string, options: [], range: range).reversed()

        for match in matches {
            guard match.numberOfRanges > 2 else { continue }

            let fullRange = match.range(at: 0)
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            guard let textStringRange = Range(textRange, in: string),
                  let urlStringRange = Range(urlRange, in: string) else { continue }

            let linkText = String(string[textStringRange])
            let linkURL = String(string[urlStringRange])

            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: linkURL
            ]

            let replacement = NSAttributedString(string: linkText, attributes: attrs)
            attributedString.replaceCharacters(in: fullRange, with: replacement)
        }
    }

    // MARK: - Code Block Rendering

    private func renderCodeBlock(_ code: String, language: String?) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Detect language from hint
        let detectedLang = language.flatMap { SyntaxLanguage(rawValue: $0.lowercased()) }

        // Try to use SyntaxHighlightingService for better highlighting
        let highlightResult = SyntaxHighlightingService.shared.highlightSync(
            code,
            language: detectedLang,
            filename: nil
        )

        // Add language label with indicator
        let langDisplay = highlightResult.language.displayName
        let indicator = highlightResult.usedFallback ? "⚡" : "✓"
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 2, weight: .medium),
            .foregroundColor: quoteColor
        ]
        result.append(NSAttributedString(string: "\(indicator) [\(langDisplay)]\n", attributes: labelAttrs))

        // Use the highlighted attributed string from the service
        result.append(highlightResult.attributedString)

        return result
    }

    private func applySyntaxHighlighting(_ code: String, language: String?) -> NSAttributedString {
        // This method is now deprecated in favor of using SyntaxHighlightingService
        // Kept for backwards compatibility but delegates to the service
        let detectedLang = language.flatMap { SyntaxLanguage(rawValue: $0.lowercased()) }
        let result = SyntaxHighlightingService.shared.highlightSync(
            code,
            language: detectedLang,
            filename: nil
        )
        return result.attributedString
    }

    private func highlightPattern(in attributedString: NSMutableAttributedString, pattern: String, color: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

        let string = attributedString.string
        let range = NSRange(location: 0, length: string.utf16.count)

        regex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)
        }
    }

    // MARK: - Base Attributes

    private func baseAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: baseFont,
            .foregroundColor: textColor
        ]
    }

    private func codeAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: codeFont,
            .foregroundColor: codeTextColor,
            .backgroundColor: codeBackgroundColor
        ]
    }
}
