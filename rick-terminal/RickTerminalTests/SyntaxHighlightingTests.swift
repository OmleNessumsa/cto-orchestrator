import XCTest
@testable import RickTerminal

/// Unit tests for syntax highlighting system
final class SyntaxHighlightingTests: XCTestCase {

    var service: SyntaxHighlightingService!
    var fallbackHighlighter: FallbackSyntaxHighlighter!

    override func setUp() {
        super.setUp()
        service = SyntaxHighlightingService.shared
        fallbackHighlighter = FallbackSyntaxHighlighter()
    }

    override func tearDown() {
        service = nil
        fallbackHighlighter = nil
        super.tearDown()
    }

    // MARK: - Language Detection Tests

    func testSwiftLanguageDetection() {
        let swiftCode = """
        import Foundation

        class HelloWorld {
            func greet() {
                print("Hello, World!")
            }
        }
        """

        let detected = service.detectLanguage(swiftCode)
        XCTAssertNotNil(detected, "Should detect Swift language")
        XCTAssertEqual(detected?.language, .swift, "Should detect as Swift")
        XCTAssertGreaterThan(detected?.confidence ?? 0, 0.3, "Confidence should be reasonable")
    }

    func testPythonLanguageDetection() {
        let pythonCode = """
        def hello_world():
            print("Hello, World!")

        if __name__ == "__main__":
            hello_world()
        """

        let detected = service.detectLanguage(pythonCode)
        XCTAssertNotNil(detected, "Should detect Python language")
        XCTAssertEqual(detected?.language, .python, "Should detect as Python")
    }

    func testJavaScriptLanguageDetection() {
        let jsCode = """
        const greeting = "Hello, World!";

        function sayHello() {
            console.log(greeting);
        }

        sayHello();
        """

        let detected = service.detectLanguage(jsCode)
        XCTAssertNotNil(detected, "Should detect JavaScript language")
        XCTAssertEqual(detected?.language, .javascript, "Should detect as JavaScript")
    }

    func testTypeScriptLanguageDetection() {
        let tsCode = """
        interface Person {
            name: string;
            age: number;
        }

        function greet(person: Person): string {
            return `Hello, ${person.name}!`;
        }
        """

        let detected = service.detectLanguage(tsCode)
        XCTAssertNotNil(detected, "Should detect TypeScript language")
        XCTAssertEqual(detected?.language, .typescript, "Should detect as TypeScript")
    }

    func testJSONLanguageDetection() {
        let jsonCode = """
        {
            "name": "Rick",
            "age": 70,
            "occupation": "Scientist"
        }
        """

        let detected = service.detectLanguage(jsonCode)
        XCTAssertNotNil(detected, "Should detect JSON language")
        XCTAssertEqual(detected?.language, .json, "Should detect as JSON")
    }

    // MARK: - File Extension Detection Tests

    func testLanguageFromFilename() {
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.swift"), .swift)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.py"), .python)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.js"), .javascript)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.ts"), .typescript)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.json"), .json)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.yaml"), .yaml)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.md"), .markdown)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.sh"), .bash)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.go"), .go)
        XCTAssertEqual(SyntaxLanguage.fromFilename("test.rs"), .rust)
    }

    func testSpecialFilenames() {
        XCTAssertEqual(SyntaxLanguage.fromFilename("Makefile"), .bash)
        XCTAssertEqual(SyntaxLanguage.fromFilename("Dockerfile"), .bash)
        XCTAssertEqual(SyntaxLanguage.fromFilename("package.json"), .json)
        XCTAssertEqual(SyntaxLanguage.fromFilename(".bashrc"), .bash)
    }

    // MARK: - Highlighting Tests

    func testHighlightSwiftCode() async {
        let swiftCode = "let message = \"Hello\""

        let result = await service.highlight(swiftCode, language: .swift)

        XCTAssertEqual(result.language, .swift, "Language should be Swift")
        XCTAssertFalse(result.attributedString.string.isEmpty, "Should have attributed string")
        XCTAssertFalse(result.ansiString.isEmpty, "Should have ANSI string")
        XCTAssertTrue(result.usedFallback, "Should use fallback highlighter")
    }

    func testHighlightWithAutoDetection() async {
        let swiftCode = """
        import Foundation

        func greet() {
            print("Hello!")
        }
        """

        let result = await service.highlight(swiftCode, language: nil)

        XCTAssertNotEqual(result.language, .plaintext, "Should auto-detect language")
        XCTAssertGreaterThan(result.detectionConfidence, 0, "Should have confidence score")
    }

    func testHighlightPerformance() async {
        let largeCode = String(repeating: "let x = 10\n", count: 1000)

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = await service.highlight(largeCode, language: .swift)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        XCTAssertLessThan(elapsed, 1000, "Should highlight 1000 lines in under 1 second")
    }

    // MARK: - Fallback Highlighter Tests

    func testFallbackSupportsAllLanguages() {
        XCTAssertTrue(fallbackHighlighter.supports(.swift))
        XCTAssertTrue(fallbackHighlighter.supports(.python))
        XCTAssertTrue(fallbackHighlighter.supports(.javascript))
        XCTAssertTrue(fallbackHighlighter.supports(.typescript))
        XCTAssertTrue(fallbackHighlighter.supports(.json))
        XCTAssertTrue(fallbackHighlighter.supports(.plaintext))
    }

    func testFallbackHighlightSwift() {
        let code = """
        func hello() {
            let message = "Hello, World!"
            print(message)
        }
        """

        let result = fallbackHighlighter.highlightSync(code, language: .swift, theme: .rickTerminal)

        XCTAssertEqual(result.language, .swift)
        XCTAssertFalse(result.attributedString.string.isEmpty)
        XCTAssertTrue(result.usedFallback)
    }

    func testFallbackANSIOutput() {
        let code = "let x = 10"

        let result = fallbackHighlighter.highlightSync(code, language: .swift, theme: .rickTerminal)

        // Should contain ANSI escape codes
        XCTAssertTrue(result.ansiString.contains("\u{001B}"), "Should contain ANSI codes")
    }

    // MARK: - Theme Tests

    func testRickTerminalTheme() {
        let theme = SyntaxTheme.rickTerminal

        XCTAssertEqual(theme.name, "Rick Terminal")

        // Verify color consistency
        XCTAssertNotNil(theme.keyword)
        XCTAssertNotNil(theme.string)
        XCTAssertNotNil(theme.comment)
        XCTAssertNotNil(theme.number)
        XCTAssertNotNil(theme.function)

        // Verify RGB conversion
        let rgb = theme.rgb(for: .keyword)
        XCTAssertGreaterThanOrEqual(rgb.r, 0)
        XCTAssertLessThanOrEqual(rgb.r, 255)
        XCTAssertGreaterThanOrEqual(rgb.g, 0)
        XCTAssertLessThanOrEqual(rgb.g, 255)
        XCTAssertGreaterThanOrEqual(rgb.b, 0)
        XCTAssertLessThanOrEqual(rgb.b, 255)
    }

    func testThemeColorMapping() {
        let theme = SyntaxTheme.rickTerminal

        XCTAssertEqual(theme.color(for: .keyword), theme.keyword)
        XCTAssertEqual(theme.color(for: .string), theme.string)
        XCTAssertEqual(theme.color(for: .comment), theme.comment)
        XCTAssertEqual(theme.color(for: .number), theme.number)
    }

    // MARK: - Service Statistics Tests

    func testServiceInitialization() {
        XCTAssertTrue(service.isInitialized, "Service should be initialized")
        XCTAssertEqual(service.currentTheme.name, "Rick Terminal")
    }

    func testServiceSupportedLanguages() {
        let languages = service.supportedLanguages

        XCTAssertGreaterThan(languages.count, 10, "Should support many languages")
        XCTAssertTrue(languages.contains(.swift))
        XCTAssertTrue(languages.contains(.python))
        XCTAssertTrue(languages.contains(.javascript))
    }

    func testServiceSynchronousHighlighting() {
        let code = "let x = 10"

        let result = service.highlightSync(code, language: .swift)

        XCTAssertEqual(result.language, .swift)
        XCTAssertFalse(result.attributedString.string.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testEmptyCodeHighlighting() async {
        let result = await service.highlight("", language: .swift)

        XCTAssertNotNil(result)
        XCTAssertTrue(result.attributedString.string.isEmpty)
    }

    func testPlaintextHighlighting() async {
        let text = "This is just plain text without any code"

        let result = await service.highlight(text, language: .plaintext)

        XCTAssertEqual(result.language, .plaintext)
    }

    // MARK: - ANSI Conversion Tests

    func testANSIConversion() {
        let code = "let x = 10"
        let tokens: [SyntaxToken] = [
            SyntaxToken(
                range: code.startIndex..<code.index(code.startIndex, offsetBy: 3),
                type: .keyword,
                text: "let"
            )
        ]

        let ansi = service.tokensToANSI(code, tokens: tokens, theme: .rickTerminal)

        XCTAssertTrue(ansi.contains("\u{001B}"), "Should contain ANSI escape codes")
        XCTAssertTrue(ansi.contains("let"), "Should contain the keyword")
    }

    // MARK: - Multiple Language Tests

    func testHighlightMultipleLanguages() async {
        let languages: [(SyntaxLanguage, String)] = [
            (.swift, "let x = 10"),
            (.python, "def hello(): pass"),
            (.javascript, "const x = 10;"),
            (.json, "{\"key\": \"value\"}"),
            (.yaml, "key: value"),
            (.markdown, "# Header")
        ]

        for (language, code) in languages {
            let result = await service.highlight(code, language: language)
            XCTAssertEqual(result.language, language, "Should highlight \(language.displayName)")
        }
    }
}
