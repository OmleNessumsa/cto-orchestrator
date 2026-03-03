import Foundation

/// Formats Claude CLI output with ANSI styling for visual distinction
/// Combines markdown rendering and visual styling via ANSI escape codes
final class ClaudeOutputFormatter {

    // MARK: - Configuration

    private let enableBorders: Bool
    private let enableMarkdown: Bool
    private let enableSyntaxHighlighting: Bool

    // MARK: - Initialization

    init(
        enableBorders: Bool = true,
        enableMarkdown: Bool = true,
        enableSyntaxHighlighting: Bool = true
    ) {
        self.enableBorders = enableBorders
        self.enableMarkdown = enableMarkdown
        self.enableSyntaxHighlighting = enableSyntaxHighlighting
    }

    // MARK: - Formatting

    /// Format Claude response text with styling
    func format(_ text: String) -> String {
        var result = text

        // First, process code blocks (they need special handling)
        result = processCodeBlocks(result)

        // Apply markdown styling if enabled
        if enableMarkdown {
            result = ANSIStyler.markdown(result)
        }

        // Apply left border for visual distinction if enabled
        if enableBorders {
            result = addLeftBorder(result)
        }

        return result
    }

    /// Format a single line (for streaming output)
    func formatLine(_ line: String, isToolLine: Bool = false) -> String {
        if isToolLine {
            return formatToolLine(line)
        }

        var result = line

        // Apply markdown styling
        if enableMarkdown {
            result = ANSIStyler.markdown(result)
        }

        // Add border
        if enableBorders {
            result = addLeftBorder(result)
        }

        return result
    }

    /// Format tool invocation line
    func formatToolLine(_ line: String) -> String {
        let styled = ANSIStyler.toolInvocation(line)
        return enableBorders ? addLeftBorder(styled) : styled
    }

    // MARK: - Code Block Processing

    private func processCodeBlocks(_ text: String) -> String {
        var result = ""
        var inCodeBlock = false
        var codeBuffer: [String] = []
        var language: String?

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End of code block - render it
                    let code = codeBuffer.joined(separator: "\n")
                    let styledCode = ANSIStyler.codeBlock(code, language: language)
                    result += styledCode + "\n"

                    codeBuffer = []
                    language = nil
                    inCodeBlock = false
                } else {
                    // Start of code block
                    language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if language?.isEmpty == true {
                        language = nil
                    }
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                codeBuffer.append(line)
            } else {
                result += line + "\n"
            }
        }

        // Handle unclosed code block
        if inCodeBlock && !codeBuffer.isEmpty {
            let code = codeBuffer.joined(separator: "\n")
            result += ANSIStyler.codeBlock(code, language: language)
        }

        return result.trimmingCharacters(in: .newlines)
    }

    // MARK: - Border Application

    private func addLeftBorder(_ text: String) -> String {
        let border = ANSIStyler.colorRGB("▎", r: ANSIStyler.rtPurple.r, g: ANSIStyler.rtPurple.g, b: ANSIStyler.rtPurple.b)

        let lines = text.components(separatedBy: .newlines)
        let borderedLines = lines.map { line -> String in
            "\(border) \(line)"
        }

        return borderedLines.joined(separator: "\n")
    }

    // MARK: - Smart Detection

    /// Detect if text is a Claude response (heuristic)
    static func looksLikeClaudeResponse(_ text: String) -> Bool {
        // Tool invocations
        if text.contains("⏺") || text.contains("●") {
            return true
        }

        // Markdown patterns
        if text.contains("```") || text.hasPrefix("#") {
            return true
        }

        // Common Claude response patterns
        let patterns = ["I'll", "I will", "Let me", "Here's", "Sure", "Based on"]
        for pattern in patterns {
            if text.hasPrefix(pattern) {
                return true
            }
        }

        return false
    }

    /// Detect if a line is a tool invocation
    static func isToolLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("⏺") || trimmed.hasPrefix("●")
    }
}

// MARK: - Streaming Support

extension ClaudeOutputFormatter {

    /// Stateful formatter for streaming output
    class StreamFormatter {
        private let formatter: ClaudeOutputFormatter
        private var buffer = ""
        private var inCodeBlock = false
        private var codeLanguage: String?

        init(formatter: ClaudeOutputFormatter = ClaudeOutputFormatter()) {
            self.formatter = formatter
        }

        /// Process a chunk of streaming output
        func process(_ chunk: String) -> String? {
            buffer += chunk

            // Only process complete lines
            guard buffer.contains("\n") else {
                return nil
            }

            var result = ""

            while let newlineRange = buffer.range(of: "\n") {
                let line = String(buffer[..<newlineRange.lowerBound])
                buffer.removeSubrange(...newlineRange.upperBound)

                // Check for code block boundaries
                if line.hasPrefix("```") {
                    if inCodeBlock {
                        // End code block
                        result += "```\n"
                        inCodeBlock = false
                        codeLanguage = nil
                    } else {
                        // Start code block
                        codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        result += "```\(codeLanguage ?? "")\n"
                        inCodeBlock = true
                    }
                } else {
                    // Format and append line
                    let isToolLine = ClaudeOutputFormatter.isToolLine(line)
                    let formatted = formatter.formatLine(line, isToolLine: isToolLine)
                    result += formatted + "\n"
                }
            }

            return result.isEmpty ? nil : result
        }

        /// Flush any remaining buffered content
        func flush() -> String? {
            guard !buffer.isEmpty else { return nil }

            let formatted = formatter.formatLine(buffer)
            buffer = ""
            return formatted
        }

        /// Reset state
        func reset() {
            buffer = ""
            inCodeBlock = false
            codeLanguage = nil
        }
    }
}
