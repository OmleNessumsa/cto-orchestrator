import Foundation
import AppKit

// MARK: - Language Definition

/// Supported programming languages for syntax highlighting
enum SyntaxLanguage: String, CaseIterable, Codable {
    case swift
    case python
    case javascript
    case typescript
    case json
    case yaml
    case markdown
    case bash
    case go
    case rust
    case html
    case css
    case sql
    case ruby
    case java
    case kotlin
    case cpp
    case c
    case csharp
    case php
    case plaintext

    /// Display name for UI
    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .bash: return "Bash"
        case .go: return "Go"
        case .rust: return "Rust"
        case .html: return "HTML"
        case .css: return "CSS"
        case .sql: return "SQL"
        case .ruby: return "Ruby"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .cpp: return "C++"
        case .c: return "C"
        case .csharp: return "C#"
        case .php: return "PHP"
        case .plaintext: return "Plain Text"
        }
    }

    /// highlight.js language identifier
    var highlightJSName: String {
        switch self {
        case .swift: return "swift"
        case .python: return "python"
        case .javascript: return "javascript"
        case .typescript: return "typescript"
        case .json: return "json"
        case .yaml: return "yaml"
        case .markdown: return "markdown"
        case .bash: return "bash"
        case .go: return "go"
        case .rust: return "rust"
        case .html: return "html"
        case .css: return "css"
        case .sql: return "sql"
        case .ruby: return "ruby"
        case .java: return "java"
        case .kotlin: return "kotlin"
        case .cpp: return "cpp"
        case .c: return "c"
        case .csharp: return "csharp"
        case .php: return "php"
        case .plaintext: return "plaintext"
        }
    }

    /// File extensions that map to this language
    var fileExtensions: [String] {
        switch self {
        case .swift: return ["swift"]
        case .python: return ["py", "pyw", "pyi"]
        case .javascript: return ["js", "mjs", "cjs", "jsx"]
        case .typescript: return ["ts", "tsx", "mts", "cts"]
        case .json: return ["json", "jsonc", "json5"]
        case .yaml: return ["yaml", "yml"]
        case .markdown: return ["md", "markdown", "mdown"]
        case .bash: return ["sh", "bash", "zsh", "fish"]
        case .go: return ["go"]
        case .rust: return ["rs"]
        case .html: return ["html", "htm", "xhtml"]
        case .css: return ["css", "scss", "sass", "less"]
        case .sql: return ["sql"]
        case .ruby: return ["rb", "ruby", "rake"]
        case .java: return ["java"]
        case .kotlin: return ["kt", "kts"]
        case .cpp: return ["cpp", "cc", "cxx", "c++", "hpp", "hxx", "h++"]
        case .c: return ["c", "h"]
        case .csharp: return ["cs"]
        case .php: return ["php", "phtml", "php3", "php4", "php5"]
        case .plaintext: return ["txt", "text", "log"]
        }
    }

    /// Detect language from file extension
    static func fromExtension(_ ext: String) -> SyntaxLanguage? {
        let lowercased = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return SyntaxLanguage.allCases.first { $0.fileExtensions.contains(lowercased) }
    }

    /// Detect language from filename
    static func fromFilename(_ filename: String) -> SyntaxLanguage? {
        let ext = (filename as NSString).pathExtension
        if !ext.isEmpty {
            return fromExtension(ext)
        }

        // Handle special filenames
        let name = filename.lowercased()
        switch name {
        case "makefile", "gnumakefile": return .bash
        case "dockerfile": return .bash
        case "gemfile", "rakefile": return .ruby
        case "podfile": return .ruby
        case "package.json", "tsconfig.json": return .json
        case ".bashrc", ".zshrc", ".bash_profile": return .bash
        default: return nil
        }
    }
}

// MARK: - Syntax Token

/// Represents a single highlighted token in the code
struct SyntaxToken {
    let range: Range<String.Index>
    let type: TokenType
    let text: String

    enum TokenType: String {
        case keyword
        case string
        case comment
        case number
        case type
        case function
        case variable
        case property
        case `operator`
        case punctuation
        case attribute
        case tag
        case constant
        case builtin
        case plain
    }
}

// MARK: - Highlight Result

/// Result of syntax highlighting operation
struct HighlightResult {
    /// The highlighted code as NSAttributedString (for UI)
    let attributedString: NSAttributedString

    /// The highlighted code with ANSI escape codes (for terminal)
    let ansiString: String

    /// Individual tokens extracted from the code
    let tokens: [SyntaxToken]

    /// Language that was used/detected
    let language: SyntaxLanguage

    /// Confidence score for auto-detection (0.0 - 1.0)
    let detectionConfidence: Double

    /// Whether highlighting was performed by primary engine or fallback
    let usedFallback: Bool

    /// Processing time in milliseconds
    let processingTimeMs: Double

    /// Create an empty/error result
    static func plain(_ code: String, language: SyntaxLanguage = .plaintext) -> HighlightResult {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white
        ]
        return HighlightResult(
            attributedString: NSAttributedString(string: code, attributes: attrs),
            ansiString: code,
            tokens: [],
            language: language,
            detectionConfidence: 0.0,
            usedFallback: true,
            processingTimeMs: 0.0
        )
    }
}

// MARK: - Theme Definition

/// Syntax highlighting color theme following Rick Terminal palette
struct SyntaxTheme {
    let name: String

    // Token colors
    let keyword: NSColor
    let string: NSColor
    let comment: NSColor
    let number: NSColor
    let type: NSColor
    let function: NSColor
    let variable: NSColor
    let property: NSColor
    let `operator`: NSColor
    let punctuation: NSColor
    let attribute: NSColor
    let tag: NSColor
    let constant: NSColor
    let builtin: NSColor
    let plain: NSColor

    // Background colors
    let background: NSColor
    let codeBlockBackground: NSColor

    /// Get color for token type
    func color(for tokenType: SyntaxToken.TokenType) -> NSColor {
        switch tokenType {
        case .keyword: return keyword
        case .string: return string
        case .comment: return comment
        case .number: return number
        case .type: return type
        case .function: return function
        case .variable: return variable
        case .property: return property
        case .operator: return `operator`
        case .punctuation: return punctuation
        case .attribute: return attribute
        case .tag: return tag
        case .constant: return constant
        case .builtin: return builtin
        case .plain: return plain
        }
    }

    /// RGB tuple for ANSI output
    func rgb(for tokenType: SyntaxToken.TokenType) -> (r: Int, g: Int, b: Int) {
        let color = color(for: tokenType)
        return (
            r: Int(color.redComponent * 255),
            g: Int(color.greenComponent * 255),
            b: Int(color.blueComponent * 255)
        )
    }
}

// MARK: - Default Rick Terminal Theme

extension SyntaxTheme {
    /// Rick Terminal dark theme
    static let rickTerminal = SyntaxTheme(
        name: "Rick Terminal",
        keyword: NSColor(red: 0.48, green: 0.47, blue: 0.67, alpha: 1.0),      // #7B78AA - Purple
        string: NSColor(red: 0.50, green: 0.99, blue: 0.31, alpha: 1.0),       // #7FFC50 - Green
        comment: NSColor(red: 0.27, green: 0.27, blue: 0.40, alpha: 1.0),      // #464467 - Muted
        number: NSColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0),       // #2196F3 - Blue
        type: NSColor(red: 1.00, green: 0.62, blue: 0.25, alpha: 1.0),         // #FF9F40 - Orange
        function: NSColor(red: 0.50, green: 0.99, blue: 0.31, alpha: 1.0),     // #7FFC50 - Green
        variable: NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),     // #FFFFFF - White
        property: NSColor(red: 0.61, green: 0.60, blue: 0.77, alpha: 1.0),     // #9B99C4 - Light Purple
        operator: NSColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1.0),     // #9CA3AF - Secondary
        punctuation: NSColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1.0),  // #9CA3AF - Secondary
        attribute: NSColor(red: 0.48, green: 0.47, blue: 0.67, alpha: 1.0),    // #7B78AA - Purple
        tag: NSColor(red: 1.00, green: 0.62, blue: 0.25, alpha: 1.0),          // #FF9F40 - Orange
        constant: NSColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0),     // #2196F3 - Blue
        builtin: NSColor(red: 0.48, green: 0.47, blue: 0.67, alpha: 1.0),      // #7B78AA - Purple
        plain: NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),        // #FFFFFF - White
        background: NSColor(red: 0.05, green: 0.06, blue: 0.06, alpha: 1.0),   // #0D1010 - Dark
        codeBlockBackground: NSColor(red: 0.12, green: 0.22, blue: 0.22, alpha: 0.6) // #1E3738 - Secondary
    )
}

// MARK: - Highlighter Protocol

/// Protocol for syntax highlighting engines
protocol SyntaxHighlighter {
    /// Highlight code with optional language hint
    /// - Parameters:
    ///   - code: Source code to highlight
    ///   - language: Optional language hint (auto-detect if nil)
    ///   - theme: Color theme to apply
    /// - Returns: HighlightResult containing styled output
    func highlight(
        _ code: String,
        language: SyntaxLanguage?,
        theme: SyntaxTheme
    ) async throws -> HighlightResult

    /// Detect language from code content
    /// - Parameter code: Source code to analyze
    /// - Returns: Tuple of detected language and confidence score
    func detectLanguage(_ code: String) -> (language: SyntaxLanguage, confidence: Double)?

    /// Check if this highlighter supports a specific language
    func supports(_ language: SyntaxLanguage) -> Bool

    /// Name of the highlighter engine
    var engineName: String { get }
}

// MARK: - Highlighting Error

/// Errors that can occur during syntax highlighting
enum SyntaxHighlightError: Error, LocalizedError {
    case unsupportedLanguage(SyntaxLanguage)
    case highlightingFailed(String)
    case engineNotAvailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let lang):
            return "Syntax highlighting not supported for \(lang.displayName)"
        case .highlightingFailed(let reason):
            return "Highlighting failed: \(reason)"
        case .engineNotAvailable:
            return "Syntax highlighting engine is not available"
        case .timeout:
            return "Syntax highlighting timed out"
        }
    }
}
