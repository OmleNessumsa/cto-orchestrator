import Foundation
import AppKit
import Combine

/// Central service for syntax highlighting in Rick Terminal
/// Coordinates between primary (HighlightSwift) and fallback (regex-based) engines
final class SyntaxHighlightingService: ObservableObject {

    // MARK: - Singleton

    static let shared = SyntaxHighlightingService()

    // MARK: - Published Properties

    @Published private(set) var currentTheme: SyntaxTheme = .rickTerminal
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var lastError: SyntaxHighlightError?

    // MARK: - Private Properties

    private var primaryHighlighter: SyntaxHighlighter?
    private let fallbackHighlighter: FallbackSyntaxHighlighter
    private let highlightQueue = DispatchQueue(label: "com.rickterminal.syntax", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Statistics

    private(set) var totalHighlights: Int = 0
    private(set) var fallbackCount: Int = 0
    private(set) var averageProcessingTimeMs: Double = 0

    // MARK: - Initialization

    private init() {
        self.fallbackHighlighter = FallbackSyntaxHighlighter()
        initializePrimaryHighlighter()
    }

    private func initializePrimaryHighlighter() {
        // NOTE: HighlightSwift integration encountered macOS 13 compatibility issues
        // The package uses #Preview macro which requires macOS 14+
        // For now, we use the fallback regex-based highlighter as primary
        // This still provides good syntax highlighting for 20 languages
        // TODO: Re-evaluate HighlightSwift when project moves to macOS 14+ or find alternative
        self.primaryHighlighter = nil
        self.isInitialized = true
    }

    // MARK: - Public API

    /// Highlight code with automatic or specified language detection
    /// - Parameters:
    ///   - code: Source code to highlight
    ///   - language: Optional language hint; auto-detects if nil
    ///   - filename: Optional filename for extension-based detection
    /// - Returns: HighlightResult with styled output
    func highlight(
        _ code: String,
        language: SyntaxLanguage? = nil,
        filename: String? = nil
    ) async -> HighlightResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Determine language
        let detectedLanguage: SyntaxLanguage
        var confidence: Double = 1.0

        if let lang = language {
            detectedLanguage = lang
        } else if let filename = filename, let lang = SyntaxLanguage.fromFilename(filename) {
            detectedLanguage = lang
        } else if let detection = detectLanguage(code) {
            detectedLanguage = detection.language
            confidence = detection.confidence
        } else {
            detectedLanguage = .plaintext
            confidence = 0.0
        }

        // Try primary highlighter first
        var result: HighlightResult
        var usedFallback = false

        if let primary = primaryHighlighter, primary.supports(detectedLanguage) {
            do {
                result = try await primary.highlight(code, language: detectedLanguage, theme: currentTheme)
            } catch {
                // Fall back to regex-based highlighter
                result = await highlightWithFallback(code, language: detectedLanguage)
                usedFallback = true
                fallbackCount += 1
            }
        } else {
            // Use fallback directly
            result = await highlightWithFallback(code, language: detectedLanguage)
            usedFallback = true
            if primaryHighlighter == nil {
                // Don't count as fallback if primary isn't initialized yet
            } else {
                fallbackCount += 1
            }
        }

        // Update statistics
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        updateStatistics(processingTime: processingTime)

        // Return result with updated metadata
        return HighlightResult(
            attributedString: result.attributedString,
            ansiString: result.ansiString,
            tokens: result.tokens,
            language: detectedLanguage,
            detectionConfidence: confidence,
            usedFallback: usedFallback,
            processingTimeMs: processingTime
        )
    }

    /// Synchronous highlight for small code snippets
    /// Use sparingly - prefer async version for better performance
    func highlightSync(
        _ code: String,
        language: SyntaxLanguage? = nil,
        filename: String? = nil
    ) -> HighlightResult {
        // For sync operations, use fallback directly to avoid blocking
        let lang = language
            ?? filename.flatMap { SyntaxLanguage.fromFilename($0) }
            ?? detectLanguage(code)?.language
            ?? .plaintext

        return fallbackHighlighter.highlightSync(code, language: lang, theme: currentTheme)
    }

    /// Detect language from code content
    /// - Parameter code: Source code to analyze
    /// - Returns: Tuple of language and confidence, or nil if unknown
    func detectLanguage(_ code: String) -> (language: SyntaxLanguage, confidence: Double)? {
        // Try primary highlighter first
        if let detection = primaryHighlighter?.detectLanguage(code) {
            return detection
        }

        // Fall back to pattern-based detection
        return fallbackHighlighter.detectLanguage(code)
    }

    /// Set the current color theme
    func setTheme(_ theme: SyntaxTheme) {
        currentTheme = theme
    }

    /// Get list of supported languages
    var supportedLanguages: [SyntaxLanguage] {
        return SyntaxLanguage.allCases.filter { lang in
            primaryHighlighter?.supports(lang) == true || fallbackHighlighter.supports(lang)
        }
    }

    /// Convert AttributedString to ANSI-styled string
    func toANSI(_ code: String, language: SyntaxLanguage) -> String {
        let result = highlightSync(code, language: language)
        return result.ansiString
    }

    // MARK: - Private Helpers

    private func highlightWithFallback(_ code: String, language: SyntaxLanguage) async -> HighlightResult {
        return await withCheckedContinuation { continuation in
            highlightQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .plain(code, language: language))
                    return
                }
                let result = self.fallbackHighlighter.highlightSync(code, language: language, theme: self.currentTheme)
                continuation.resume(returning: result)
            }
        }
    }

    private func updateStatistics(processingTime: Double) {
        totalHighlights += 1
        let count = Double(totalHighlights)
        averageProcessingTimeMs = ((averageProcessingTimeMs * (count - 1)) + processingTime) / count
    }
}

// MARK: - ANSI Conversion Extension

extension SyntaxHighlightingService {

    /// Convert tokens to ANSI-escaped string
    func tokensToANSI(_ code: String, tokens: [SyntaxToken], theme: SyntaxTheme) -> String {
        guard !tokens.isEmpty else {
            return code
        }

        var result = ""
        var lastIndex = code.startIndex

        for token in tokens.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            // Add any text between tokens
            if token.range.lowerBound > lastIndex {
                let between = String(code[lastIndex..<token.range.lowerBound])
                result += between
            }

            // Add styled token
            let rgb = theme.rgb(for: token.type)
            let ansiCode = "\u{001B}[38;2;\(rgb.r);\(rgb.g);\(rgb.b)m"
            let resetCode = "\u{001B}[0m"
            result += "\(ansiCode)\(token.text)\(resetCode)"

            lastIndex = token.range.upperBound
        }

        // Add remaining text
        if lastIndex < code.endIndex {
            result += String(code[lastIndex...])
        }

        return result
    }
}
