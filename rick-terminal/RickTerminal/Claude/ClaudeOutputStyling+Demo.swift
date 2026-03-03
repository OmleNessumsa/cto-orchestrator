import Foundation

#if DEBUG

/// Demo and testing utilities for Claude output styling
enum ClaudeOutputStylingDemo {

    // MARK: - Sample Output

    static let sampleClaudeResponse = """
I'll help you implement that feature. Let me break this down:

## Implementation Plan

Here's what we need to do:

1. Create the data model
2. Build the UI components
3. Add networking layer

### Code Example

Here's a simple implementation:

```swift
struct Feature {
    let id: UUID
    let name: String
    let enabled: Bool
}

class FeatureManager {
    func toggle(_ feature: Feature) -> Feature {
        return Feature(
            id: feature.id,
            name: feature.name,
            enabled: !feature.enabled
        )
    }
}
```

You can also use `inline code` like this for small snippets.

**Important**: Make sure to handle errors properly.

*This is italic text* for emphasis.
"""

    static let sampleToolInvocation = """
⏺ Read(file_path: "/Users/morty/project/src/main.swift")
"""

    static let sampleToolResult = """
● Read completed successfully
"""

    static let sampleError = """
Error: File not found at path /Users/morty/project/missing.swift
"""

    // MARK: - Demo Functions

    /// Print styled output examples to console
    static func printStyleExamples() {
        print("\n=== Claude Output Styling Demo ===\n")

        // Basic ANSI styling
        print("1. Basic ANSI Colors:")
        print(ANSIStyler.colorRGB("Purple text", r: 123, g: 120, b: 170))
        print(ANSIStyler.colorRGB("Green text", r: 127, g: 252, b: 80))
        print(ANSIStyler.colorRGB("Orange text", r: 255, g: 159, b: 64))

        print("\n2. Styled Text:")
        print(ANSIStyler.style("Bold text", .bold))
        print(ANSIStyler.style("Italic text", .italic))
        print(ANSIStyler.styled("Bold + Underline", styles: [.bold, .underline]))

        print("\n3. Code Blocks:")
        let code = """
        func hello() {
            print("Hello, world!")
        }
        """
        print(ANSIStyler.codeBlock(code, language: "swift"))

        print("\n4. Inline Code:")
        print("Use \(ANSIStyler.inlineCode("let x = 5")) to declare variables.")

        print("\n5. Headers:")
        print(ANSIStyler.header("Main Header", level: 1))
        print(ANSIStyler.header("Sub Header", level: 2))

        print("\n6. Tool Invocation:")
        print(ANSIStyler.toolInvocation(sampleToolInvocation))

        print("\n7. Error Message:")
        print(ANSIStyler.error(sampleError))

        print("\n8. Claude Response (with border):")
        print(ANSIStyler.claudeResponse("This is a Claude response\nwith multiple lines\nand a purple border"))

        print("\n9. Markdown Styling:")
        let markdown = "# Header\n\nThis is **bold** and *italic* with `code`."
        print(ANSIStyler.markdown(markdown))

        print("\n=== End Demo ===\n")
    }

    /// Test the output formatter
    static func testFormatter() {
        print("\n=== Formatter Test ===\n")

        let formatter = ClaudeOutputFormatter()
        let styled = formatter.format(sampleClaudeResponse)

        print("Original:")
        print(sampleClaudeResponse)
        print("\nStyled:")
        print(styled)

        print("\n=== End Test ===\n")
    }

    /// Test streaming formatter
    static func testStreamFormatter() {
        print("\n=== Stream Formatter Test ===\n")

        let streamFormatter = ClaudeOutputFormatter.StreamFormatter()

        let chunks = [
            "I'll help you ",
            "with that.\n",
            "\n",
            "Here's some `code`:\n",
            "\n",
            "```swift\n",
            "let x = 5\n",
            "```\n"
        ]

        for chunk in chunks {
            if let formatted = streamFormatter.process(chunk) {
                print("Formatted chunk:")
                print(formatted)
                print("---")
            }
        }

        if let remaining = streamFormatter.flush() {
            print("Flushed:")
            print(remaining)
        }

        print("\n=== End Stream Test ===\n")
    }

    /// Test detector
    static func testDetector() {
        print("\n=== Detector Test ===\n")

        let detector = ClaudeOutputDetector()

        var events: [String] = []

        _ = detector.eventPublisher.sink { event in
            switch event {
            case .claudeResponseStart:
                events.append("START")
            case .claudeResponseChunk(let text):
                events.append("CHUNK: \(text)")
            case .claudeResponseEnd:
                events.append("END")
            case .toolInvocation(let tool):
                events.append("TOOL: \(tool)")
            case .regularOutput(let text):
                events.append("REGULAR: \(text)")
            }
        }

        // Simulate terminal output
        detector.process("claude> ")
        detector.process("I'll help you with that.\n")
        detector.process("⏺ Read(file_path: \"/tmp/test.txt\")\n")
        detector.process("$ ")

        detector.flush()

        print("Events detected:")
        for event in events {
            print("  - \(event)")
        }

        print("\n=== End Detector Test ===\n")
    }

    /// Run all demos
    static func runAll() {
        printStyleExamples()
        testFormatter()
        testStreamFormatter()
        testDetector()
    }
}

// MARK: - String Styling Extensions Demo

extension ClaudeOutputStylingDemo {
    static func testStringExtensions() {
        print("\n=== String Extension Test ===\n")

        let text = "Hello, world!"

        print("Original: \(text)")
        print("Green: \(text.ansiForeground(.green))")
        print("Bold: \(text.ansiStyle(.bold))")
        print("As Claude: \(text.asClaudeResponse())")

        let code = "func test() { }"
        print("As code block: \(code.asCodeBlock(language: "swift"))")

        let markdown = "**Bold** and *italic*"
        print("Markdown: \(markdown.markdownStyled())")

        print("\n=== End Extension Test ===\n")
    }
}

#endif
