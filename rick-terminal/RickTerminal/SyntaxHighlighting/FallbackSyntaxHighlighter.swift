import Foundation
import AppKit

/// Regex-based syntax highlighter used as fallback when primary engine is unavailable
/// Provides basic but fast highlighting for common languages
final class FallbackSyntaxHighlighter: SyntaxHighlighter {

    // MARK: - SyntaxHighlighter Protocol

    var engineName: String { "Fallback (Regex)" }

    func highlight(
        _ code: String,
        language: SyntaxLanguage?,
        theme: SyntaxTheme
    ) async throws -> HighlightResult {
        return highlightSync(code, language: language ?? .plaintext, theme: theme)
    }

    func detectLanguage(_ code: String) -> (language: SyntaxLanguage, confidence: Double)? {
        // Score each language based on pattern matches
        var scores: [(SyntaxLanguage, Double)] = []

        for language in SyntaxLanguage.allCases where language != .plaintext {
            let score = calculateLanguageScore(code, language: language)
            if score > 0 {
                scores.append((language, score))
            }
        }

        // Return highest scoring language
        guard let best = scores.max(by: { $0.1 < $1.1 }), best.1 >= 0.3 else {
            return nil
        }

        return best
    }

    func supports(_ language: SyntaxLanguage) -> Bool {
        // Support all languages with at least basic highlighting
        return true
    }

    // MARK: - Synchronous Highlighting

    func highlightSync(_ code: String, language: SyntaxLanguage, theme: SyntaxTheme) -> HighlightResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Build attributed string
        let attributedString = buildAttributedString(code, language: language, theme: theme)

        // Build ANSI string
        let ansiString = buildANSIString(code, language: language, theme: theme)

        // Extract tokens (simplified)
        let tokens = extractTokens(code, language: language)

        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return HighlightResult(
            attributedString: attributedString,
            ansiString: ansiString,
            tokens: tokens,
            language: language,
            detectionConfidence: 1.0,
            usedFallback: true,
            processingTimeMs: processingTime
        )
    }

    // MARK: - Language Detection Patterns

    private func calculateLanguageScore(_ code: String, language: SyntaxLanguage) -> Double {
        let patterns = detectionPatterns(for: language)
        var matchCount = 0

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let range = NSRange(code.startIndex..., in: code)
                matchCount += regex.numberOfMatches(in: code, range: range)
            }
        }

        // Normalize by code length
        let codeLength = max(code.count, 100)
        return min(Double(matchCount) / Double(codeLength) * 100, 1.0)
    }

    private func detectionPatterns(for language: SyntaxLanguage) -> [String] {
        switch language {
        case .swift:
            return [
                #"\bimport\s+(Foundation|UIKit|SwiftUI|AppKit)\b"#,
                #"\bfunc\s+\w+\s*\("#,
                #"\b(let|var)\s+\w+\s*[:=]"#,
                #"\bclass\s+\w+\s*[:{]"#,
                #"\bstruct\s+\w+\s*[:{]"#,
                #"\benum\s+\w+\s*[:{]"#,
                #"\bguard\s+let\b"#,
                #"\bif\s+let\b"#,
                #"@\w+\s*(struct|class|func|var)"#
            ]
        case .python:
            return [
                #"^import\s+\w+"#,
                #"^from\s+\w+\s+import"#,
                #"\bdef\s+\w+\s*\("#,
                #"\bclass\s+\w+\s*[:\(]"#,
                #"^\s*if\s+.*:\s*$"#,
                #"^\s*for\s+.*:\s*$"#,
                #"^\s*elif\s+"#,
                #"\bself\."#
            ]
        case .javascript:
            return [
                #"\bconst\s+\w+\s*="#,
                #"\blet\s+\w+\s*="#,
                #"\bfunction\s+\w+\s*\("#,
                #"\b=>\s*\{"#,
                #"\bconsole\.(log|error|warn)"#,
                #"\brequire\s*\("#,
                #"\bmodule\.exports\b"#,
                #"\basync\s+function\b"#
            ]
        case .typescript:
            return [
                #"\binterface\s+\w+\s*\{"#,
                #"\btype\s+\w+\s*="#,
                #":\s*(string|number|boolean|void|any)\b"#,
                #"\b<\w+>\s*\("#,
                #"\bas\s+\w+"#,
                #"\bexport\s+(interface|type|enum)"#
            ]
        case .json:
            return [
                #"^\s*\{"#,
                #"^\s*\["#,
                #""\w+":\s*["\d\[\{tfn]"#
            ]
        case .yaml:
            return [
                #"^\w[\w-]*:\s+"#,
                #"^\s+-\s+"#,
                #"^---\s*$"#
            ]
        case .markdown:
            return [
                #"^#{1,6}\s+"#,
                #"\*\*\w+\*\*"#,
                #"\[.+\]\(.+\)"#,
                #"^```"#
            ]
        case .bash:
            return [
                #"^#!/bin/(ba)?sh"#,
                #"^\$\s+"#,
                #"\becho\s+"#,
                #"\bif\s+\[\["#,
                #"\bfor\s+\w+\s+in\b"#
            ]
        case .go:
            return [
                #"\bpackage\s+\w+"#,
                #"\bfunc\s+(\(\w+\s+\*?\w+\)\s+)?\w+\("#,
                #"\bimport\s+\("#,
                #"\b:=\s+"#,
                #"\bgo\s+\w+"#
            ]
        case .rust:
            return [
                #"\bfn\s+\w+\s*[<\(]"#,
                #"\blet\s+mut\s+"#,
                #"\bimpl\s+\w+"#,
                #"\bstruct\s+\w+\s*\{"#,
                #"\buse\s+\w+"#,
                #"\bpub\s+(fn|struct|enum)"#
            ]
        case .html:
            return [
                #"<(!DOCTYPE|html|head|body|div|span|p)"#,
                #"</\w+>"#,
                #"<\w+\s+\w+="#
            ]
        case .css:
            return [
                #"^\s*\.\w+\s*\{"#,
                #"^\s*#\w+\s*\{"#,
                #"\b(color|background|margin|padding|font|display):"#
            ]
        case .sql:
            return [
                #"\b(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|JOIN)\b"#,
                #"\bCREATE\s+(TABLE|INDEX|VIEW)\b"#
            ]
        default:
            return []
        }
    }

    // MARK: - Attributed String Building

    private func buildAttributedString(_ code: String, language: SyntaxLanguage, theme: SyntaxTheme) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let result = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: font,
                .foregroundColor: theme.plain,
                .backgroundColor: theme.codeBlockBackground
            ]
        )

        // Apply syntax patterns
        let patterns = highlightPatterns(for: language)

        for (pattern, tokenType) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }

            let range = NSRange(code.startIndex..., in: code)
            regex.enumerateMatches(in: code, range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }
                result.addAttribute(.foregroundColor, value: theme.color(for: tokenType), range: matchRange)
            }
        }

        return result
    }

    // MARK: - ANSI String Building

    private func buildANSIString(_ code: String, language: SyntaxLanguage, theme: SyntaxTheme) -> String {
        var result = code
        let patterns = highlightPatterns(for: language)

        // Sort patterns by specificity (longer patterns first)
        let sortedPatterns = patterns.sorted { $0.0.count > $1.0.count }

        for (pattern, tokenType) in sortedPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }

            let rgb = theme.rgb(for: tokenType)
            let startCode = "\u{001B}[38;2;\(rgb.r);\(rgb.g);\(rgb.b)m"
            let endCode = "\u{001B}[0m"

            // Find and replace matches (in reverse to maintain indices)
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let matchRange = Range(match.range, in: result) else { continue }
                let matchText = String(result[matchRange])
                result.replaceSubrange(matchRange, with: "\(startCode)\(matchText)\(endCode)")
            }
        }

        return result
    }

    // MARK: - Token Extraction

    private func extractTokens(_ code: String, language: SyntaxLanguage) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let patterns = highlightPatterns(for: language)

        for (pattern, tokenType) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }

            let range = NSRange(code.startIndex..., in: code)
            regex.enumerateMatches(in: code, range: range) { match, _, _ in
                guard let matchRange = match?.range,
                      let swiftRange = Range(matchRange, in: code) else { return }

                let token = SyntaxToken(
                    range: swiftRange,
                    type: tokenType,
                    text: String(code[swiftRange])
                )
                tokens.append(token)
            }
        }

        return tokens
    }

    // MARK: - Highlight Patterns per Language

    private func highlightPatterns(for language: SyntaxLanguage) -> [(String, SyntaxToken.TokenType)] {
        var patterns: [(String, SyntaxToken.TokenType)] = []

        // Common patterns for most languages
        let commonPatterns: [(String, SyntaxToken.TokenType)] = [
            // Comments
            (#"//.*$"#, .comment),
            (#"/\*[\s\S]*?\*/"#, .comment),

            // Strings
            (#""(?:[^"\\]|\\.)*""#, .string),
            (#"'(?:[^'\\]|\\.)*'"#, .string),

            // Numbers
            (#"\b\d+\.?\d*\b"#, .number),
            (#"\b0x[0-9A-Fa-f]+\b"#, .number),
        ]

        patterns.append(contentsOf: commonPatterns)

        // Language-specific patterns
        switch language {
        case .swift:
            patterns.append(contentsOf: [
                (#"\b(import|func|class|struct|enum|protocol|extension|let|var|if|else|guard|switch|case|default|for|while|repeat|return|break|continue|throw|throws|try|catch|as|is|in|where|self|super|init|deinit|get|set|willSet|didSet|lazy|static|final|override|private|public|internal|fileprivate|open|mutating|nonmutating|dynamic|optional|required|convenience|associatedtype|typealias|some|any|async|await|actor|nonisolated|isolated)\b"#, .keyword),
                (#"@\w+"#, .attribute),
                (#"\b(String|Int|Double|Float|Bool|Array|Dictionary|Set|Optional|Any|AnyObject|Void|Never)\b"#, .type),
                (#"\b[A-Z][a-zA-Z0-9_]*\b"#, .type),
                (#"#\w+\b"#, .builtin),
            ])

        case .python:
            patterns.append(contentsOf: [
                (#"#.*$"#, .comment),
                (#"\"\"\"[\s\S]*?\"\"\""#, .string),
                (#"'''[\s\S]*?'''"#, .string),
                (#"\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|True|False|None)\b"#, .keyword),
                (#"\bself\b"#, .variable),
                (#"@\w+"#, .attribute),
                (#"\b(int|float|str|bool|list|dict|set|tuple|type|object|Exception)\b"#, .type),
            ])

        case .javascript, .typescript:
            patterns.append(contentsOf: [
                (#"`(?:[^`\\]|\\.)*`"#, .string), // Template strings
                (#"\b(async|await|break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|function|if|import|in|instanceof|let|new|of|return|super|switch|this|throw|try|typeof|var|void|while|with|yield)\b"#, .keyword),
                (#"\b(console|window|document|require|module|exports|process)\b"#, .builtin),
                (#"\b[A-Z][a-zA-Z0-9_]*\b"#, .type),
                (#"=>"#, .operator),
            ])

            if language == .typescript {
                patterns.append(contentsOf: [
                    (#"\b(interface|type|enum|namespace|declare|implements|abstract|readonly|keyof|infer|never|unknown|asserts)\b"#, .keyword),
                    (#":\s*(string|number|boolean|void|any|unknown|never|object)\b"#, .type),
                    (#"<[^>]+>"#, .type),
                ])
            }

        case .json:
            patterns.append(contentsOf: [
                (#""\w+"(?=\s*:)"#, .property),
                (#"\b(true|false|null)\b"#, .constant),
            ])

        case .yaml:
            patterns.append(contentsOf: [
                (#"#.*$"#, .comment),
                (#"^[\w-]+(?=:)"#, .property),
                (#"\b(true|false|null|yes|no|on|off)\b"#, .constant),
            ])

        case .markdown:
            patterns.append(contentsOf: [
                (#"^#{1,6}\s+.*$"#, .keyword),
                (#"\*\*[^*]+\*\*"#, .keyword),
                (#"\*[^*]+\*"#, .string),
                (#"`[^`]+`"#, .string),
                (#"\[[^\]]+\]\([^\)]+\)"#, .function),
            ])

        case .bash:
            patterns.append(contentsOf: [
                (#"#.*$"#, .comment),
                (#"\$\w+"#, .variable),
                (#"\$\{[^}]+\}"#, .variable),
                (#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|exit|local|export|source|alias|unalias|echo|printf|read|cd|pwd|ls|rm|cp|mv|mkdir|chmod|chown|grep|sed|awk|find|xargs|cat|head|tail|sort|uniq|wc|cut|tr|tee)\b"#, .keyword),
            ])

        case .go:
            patterns.append(contentsOf: [
                (#"\b(break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var)\b"#, .keyword),
                (#"\b(bool|byte|complex64|complex128|error|float32|float64|int|int8|int16|int32|int64|rune|string|uint|uint8|uint16|uint32|uint64|uintptr)\b"#, .type),
                (#"\b(nil|true|false|iota)\b"#, .constant),
                (#"\b(append|cap|close|complex|copy|delete|imag|len|make|new|panic|print|println|real|recover)\b"#, .builtin),
            ])

        case .rust:
            patterns.append(contentsOf: [
                (#"\b(as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while)\b"#, .keyword),
                (#"\b(i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Option|Result|Box|Rc|Arc|Cell|RefCell)\b"#, .type),
                (#"'\w+"#, .attribute), // Lifetimes
                (#"#\[[\w:]+\]"#, .attribute), // Attributes
                (#"\b(println|print|vec|format|panic|assert|debug_assert)\!"#, .builtin),
            ])

        case .html:
            patterns.append(contentsOf: [
                (#"<!--[\s\S]*?-->"#, .comment),
                (#"</?[a-zA-Z][a-zA-Z0-9]*"#, .tag),
                (#"\s[a-zA-Z-]+(?==)"#, .attribute),
                (#">"#, .punctuation),
            ])

        case .css:
            patterns.append(contentsOf: [
                (#"/\*[\s\S]*?\*/"#, .comment),
                (#"\.[a-zA-Z][a-zA-Z0-9_-]*"#, .type), // Class selectors
                (#"#[a-zA-Z][a-zA-Z0-9_-]*"#, .type), // ID selectors
                (#"[a-zA-Z-]+(?=:)"#, .property),
                (#":\s*[^;{]+"#, .string),
            ])

        case .sql:
            patterns.append(contentsOf: [
                (#"--.*$"#, .comment),
                (#"\b(SELECT|FROM|WHERE|AND|OR|NOT|IN|LIKE|BETWEEN|IS|NULL|AS|ON|JOIN|LEFT|RIGHT|INNER|OUTER|FULL|CROSS|UNION|ALL|DISTINCT|ORDER|BY|ASC|DESC|GROUP|HAVING|LIMIT|OFFSET|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|DROP|ALTER|TABLE|INDEX|VIEW|DATABASE|SCHEMA|PRIMARY|KEY|FOREIGN|REFERENCES|CONSTRAINT|UNIQUE|CHECK|DEFAULT|AUTO_INCREMENT|CASCADE|TRIGGER|PROCEDURE|FUNCTION|BEGIN|END|DECLARE|IF|THEN|ELSE|WHILE|LOOP|RETURN|COMMIT|ROLLBACK|TRANSACTION)\b"#, .keyword),
                (#"\b(INT|INTEGER|SMALLINT|BIGINT|DECIMAL|NUMERIC|FLOAT|REAL|DOUBLE|CHAR|VARCHAR|TEXT|BLOB|DATE|TIME|DATETIME|TIMESTAMP|BOOLEAN|BOOL)\b"#, .type),
            ])

        case .ruby:
            patterns.append(contentsOf: [
                (#"#.*$"#, .comment),
                (#"\b(alias|and|begin|break|case|class|def|defined\?|do|else|elsif|end|ensure|false|for|if|in|module|next|nil|not|or|redo|rescue|retry|return|self|super|then|true|undef|unless|until|when|while|yield|require|require_relative|include|extend|attr_reader|attr_writer|attr_accessor|private|protected|public)\b"#, .keyword),
                (#":\w+"#, .constant), // Symbols
                (#"@\w+"#, .variable), // Instance variables
                (#"@@\w+"#, .variable), // Class variables
                (#"\$\w+"#, .variable), // Global variables
            ])

        case .java, .kotlin:
            patterns.append(contentsOf: [
                (#"\b(abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|void|volatile|while)\b"#, .keyword),
                (#"@\w+"#, .attribute),
                (#"\b[A-Z][a-zA-Z0-9_]*\b"#, .type),
            ])

            if language == .kotlin {
                patterns.append(contentsOf: [
                    (#"\b(as|as\?|by|companion|constructor|crossinline|data|dynamic|fun|get|in|infix|init|inline|inner|internal|is|it|lateinit|noinline|object|open|operator|out|override|reified|sealed|set|suspend|tailrec|typealias|val|var|vararg|when|where)\b"#, .keyword),
                ])
            }

        case .cpp, .c:
            patterns.append(contentsOf: [
                (#"\b(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while)\b"#, .keyword),
                (#"#\w+"#, .builtin), // Preprocessor
                (#"\b(NULL|nullptr|true|false)\b"#, .constant),
            ])

            if language == .cpp {
                patterns.append(contentsOf: [
                    (#"\b(alignas|alignof|and|and_eq|asm|bitand|bitor|bool|catch|class|compl|const_cast|constexpr|decltype|delete|dynamic_cast|explicit|export|false|friend|inline|mutable|namespace|new|noexcept|not|not_eq|nullptr|operator|or|or_eq|private|protected|public|reinterpret_cast|static_assert|static_cast|template|this|thread_local|throw|true|try|typeid|typename|using|virtual|wchar_t|xor|xor_eq|override|final)\b"#, .keyword),
                    (#"\b(std)::\w+"#, .type),
                ])
            }

        case .csharp:
            patterns.append(contentsOf: [
                (#"\b(abstract|as|base|bool|break|byte|case|catch|char|checked|class|const|continue|decimal|default|delegate|do|double|else|enum|event|explicit|extern|false|finally|fixed|float|for|foreach|goto|if|implicit|in|int|interface|internal|is|lock|long|namespace|new|null|object|operator|out|override|params|private|protected|public|readonly|ref|return|sbyte|sealed|short|sizeof|stackalloc|static|string|struct|switch|this|throw|true|try|typeof|uint|ulong|unchecked|unsafe|ushort|using|virtual|void|volatile|while|async|await|dynamic|nameof|var|when|yield)\b"#, .keyword),
                (#"@\w+"#, .attribute),
                (#"\b[A-Z][a-zA-Z0-9_]*\b"#, .type),
            ])

        case .php:
            patterns.append(contentsOf: [
                (#"#.*$"#, .comment),
                (#"\$\w+"#, .variable),
                (#"\b(abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|die|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|namespace|new|or|print|private|protected|public|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield|yield from)\b"#, .keyword),
                (#"\b(true|false|null|TRUE|FALSE|NULL)\b"#, .constant),
            ])

        case .plaintext:
            // No special patterns
            break
        }

        return patterns
    }
}
