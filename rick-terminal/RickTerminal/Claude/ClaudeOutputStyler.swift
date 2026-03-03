import Foundation
import AppKit

/// Applies visual styling to Claude CLI output to distinguish it from regular terminal output
/// Adds left border, subtle background, and markdown rendering
final class ClaudeOutputStyler {

    // MARK: - Properties

    private let markdownRenderer: MarkdownRenderer
    private let borderColor: NSColor
    private let backgroundColor: NSColor
    private let baseFontSize: CGFloat

    // MARK: - Output Detection

    /// Patterns that indicate Claude is responding
    private let claudeIndicators = [
        "⏺",           // Tool usage indicator
        "●",           // Tool completion indicator
        "assistant:",  // Message prefix (in some modes)
        "thinking:",   // Thinking block
        "<thinking>",  // Thinking tag
    ]

    // MARK: - State

    private var isInClaudeResponse = false
    private var responseBuffer = ""
    private var lastWasToolLine = false

    // MARK: - Initialization

    init(
        fontSize: CGFloat = 12,
        borderColor: NSColor = NSColor(red: 0.48, green: 0.47, blue: 0.67, alpha: 0.5), // rtAccentPurple with alpha
        backgroundColor: NSColor = NSColor(red: 0.12, green: 0.22, blue: 0.22, alpha: 0.15) // rtBackgroundSecondary with low alpha
    ) {
        self.baseFontSize = fontSize
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.markdownRenderer = MarkdownRenderer(baseFontSize: fontSize)
    }

    // MARK: - Public API

    /// Process a chunk of terminal output and return styled version if it's Claude output
    /// Returns nil if this is not Claude output
    func processChunk(_ text: String) -> StyledOutput? {
        // Check if this looks like Claude output
        if detectClaudeOutput(text) {
            isInClaudeResponse = true
            responseBuffer += text
            return nil // Don't style yet, wait for more content
        }

        // If we're in a Claude response and this is a continuation
        if isInClaudeResponse {
            // Check if this ends the Claude response
            if detectEndOfResponse(text) {
                responseBuffer += text
                let styled = styleClaudeResponse(responseBuffer)

                // Reset state
                responseBuffer = ""
                isInClaudeResponse = false

                return styled
            } else {
                // Continue buffering
                responseBuffer += text
                return nil
            }
        }

        // Not Claude output
        return nil
    }

    /// Force completion of any buffered response (e.g., on stream end)
    func flush() -> StyledOutput? {
        guard !responseBuffer.isEmpty else { return nil }

        let styled = styleClaudeResponse(responseBuffer)
        responseBuffer = ""
        isInClaudeResponse = false

        return styled
    }

    /// Reset internal state
    func reset() {
        responseBuffer = ""
        isInClaudeResponse = false
        lastWasToolLine = false
    }

    // MARK: - Detection

    private func detectClaudeOutput(_ text: String) -> Bool {
        // Check for Claude indicators
        for indicator in claudeIndicators {
            if text.contains(indicator) {
                return true
            }
        }

        // Check for markdown-like patterns (headers, code blocks)
        if text.contains("```") || text.contains("# ") || text.hasPrefix("## ") {
            return true
        }

        return false
    }

    private func detectEndOfResponse(_ text: String) -> Bool {
        // End if we see a new prompt or user input
        if text.contains("$ ") || text.contains("% ") {
            return true
        }

        // End if we see a new tool invocation after some output
        if !responseBuffer.isEmpty && (text.contains("⏺") || text.contains("●")) {
            return true
        }

        // Otherwise continue buffering
        return false
    }

    // MARK: - Styling

    private func styleClaudeResponse(_ text: String) -> StyledOutput {
        // First, render markdown
        let renderedMarkdown = markdownRenderer.render(text)

        // Then apply visual distinction (left border + background)
        let styledText = applyVisualDistinction(to: renderedMarkdown)

        return StyledOutput(
            attributedText: styledText,
            plainText: text
        )
    }

    private func applyVisualDistinction(to attributedString: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedString)

        // Apply subtle background to entire text
        let fullRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.backgroundColor, value: backgroundColor, range: fullRange)

        // Add left border effect using paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 8 // Indent to make room for visual "border"
        paragraphStyle.firstLineHeadIndent = 8

        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        // Add a visual "border" marker at the start
        let borderMarker = NSAttributedString(string: "▎ ", attributes: [
            .foregroundColor: borderColor,
            .font: NSFont.systemFont(ofSize: baseFontSize)
        ])

        // Insert border marker at the beginning
        result.insert(borderMarker, at: 0)

        // Add border markers at each newline
        let text = result.string
        var offset = 0
        for (index, char) in text.enumerated() {
            if char == "\n" && index < text.count - 1 {
                let insertionPoint = index + 1 + offset
                if insertionPoint < result.length {
                    result.insert(borderMarker, at: insertionPoint)
                    offset += borderMarker.length
                }
            }
        }

        return result
    }

    // MARK: - Utilities

    /// Detect if a line is a tool invocation (for special handling)
    func isToolLine(_ line: String) -> Bool {
        return line.hasPrefix("⏺") || line.hasPrefix("●")
    }

    /// Extract plain text from styled output
    static func extractPlainText(_ attributedString: NSAttributedString) -> String {
        return attributedString.string
    }
}

// MARK: - Styled Output Model

/// Represents styled Claude output
struct StyledOutput {
    /// The styled attributed string ready for display
    let attributedText: NSAttributedString

    /// The original plain text
    let plainText: String

    /// Whether this output contains a tool invocation
    var containsToolInvocation: Bool {
        plainText.contains("⏺") || plainText.contains("●")
    }

    /// Whether this output contains code blocks
    var containsCodeBlock: Bool {
        plainText.contains("```")
    }
}

// MARK: - Output Type Detection

extension ClaudeOutputStyler {

    /// Classify the type of Claude output
    enum OutputType {
        case text              // Regular text response
        case thinking          // Thinking/reasoning block
        case toolInvocation    // Tool being invoked
        case toolResult        // Tool result output
        case codeBlock         // Code block
        case error             // Error message
    }

    func detectOutputType(_ text: String) -> OutputType {
        if text.contains("<thinking>") || text.contains("thinking:") {
            return .thinking
        }

        if text.hasPrefix("⏺") {
            return .toolInvocation
        }

        if text.hasPrefix("●") {
            return .toolResult
        }

        if text.contains("```") {
            return .codeBlock
        }

        if text.lowercased().contains("error:") || text.lowercased().contains("failed:") {
            return .error
        }

        return .text
    }

    /// Apply type-specific styling hints
    func styleByType(_ text: String, type: OutputType) -> NSAttributedString {
        let baseStyled = markdownRenderer.render(text)
        let result = NSMutableAttributedString(attributedString: baseStyled)

        switch type {
        case .thinking:
            // Add subtle italic hint for thinking blocks
            let fullRange = NSRange(location: 0, length: result.length)
            result.addAttribute(.obliqueness, value: 0.1, range: fullRange)

        case .error:
            // Tint errors with orange
            let errorColor = NSColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1.0) // rtAccentOrange
            let fullRange = NSRange(location: 0, length: result.length)
            result.addAttribute(.foregroundColor, value: errorColor, range: fullRange)

        case .toolInvocation, .toolResult, .codeBlock, .text:
            // Use default styling
            break
        }

        return result
    }
}
