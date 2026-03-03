#!/usr/bin/env swift

// Standalone test script for Claude output styling
// Run with: swift scripts/test-claude-styling.swift

import Foundation

// MARK: - Embedded ANSIStyler (simplified version)

struct ANSIStyler {
    static let rtPurple = (r: 123, g: 120, b: 170)
    static let rtGreen = (r: 127, g: 252, b: 80)
    static let rtOrange = (r: 255, g: 159, b: 64)

    static func rgb(_ text: String, r: Int, g: Int, b: Int) -> String {
        return "\u{001B}[38;2;\(r);\(g);\(b)m\(text)\u{001B}[0m"
    }

    static func claudeResponse(_ text: String) -> String {
        let border = rgb("▎", r: rtPurple.r, g: rtPurple.g, b: rtPurple.b)
        let lines = text.components(separatedBy: .newlines)
        let styled = lines.map { "\(border) \($0)" }
        return styled.joined(separator: "\n")
    }

    static func codeBlock(_ code: String, language: String? = nil) -> String {
        var result = ""
        if let lang = language {
            result += rgb("[\(lang)]", r: 70, g: 68, b: 103) + "\n"
        }
        let lines = code.components(separatedBy: .newlines)
        result += lines.map { rgb($0, r: rtGreen.r, g: rtGreen.g, b: rtGreen.b) }.joined(separator: "\n")
        return result
    }
}

// MARK: - Test Examples

print("\n=== Claude Output Styling Test ===\n")

// Example 1: Simple Claude response
let response1 = """
I'll help you implement that feature.
Let me break this down into steps.
"""

print("Example 1: Simple Response")
print(ANSIStyler.claudeResponse(response1))

// Example 2: Response with code block
print("\n\nExample 2: Code Block")
let code = """
func hello() {
    print("Hello, world!")
}
"""
print(ANSIStyler.codeBlock(code, language: "swift"))

// Example 3: Full Claude response with styling
print("\n\nExample 3: Full Styled Response")
let fullResponse = """
I'll create a new Swift struct for you.

Here's the implementation:
"""

print(ANSIStyler.claudeResponse(fullResponse))
print("\n" + ANSIStyler.claudeResponse(ANSIStyler.codeBlock(code, language: "swift")))

print("\n\nExample 4: Tool Invocation")
let tool = "⏺ Read(file_path: \"/Users/morty/test.swift\")"
print(ANSIStyler.rgb(tool, r: ANSIStyler.rtPurple.r, g: ANSIStyler.rtPurple.g, b: ANSIStyler.rtPurple.b))

print("\n\nExample 5: Error Message")
let error = "Error: File not found"
print(ANSIStyler.rgb(error, r: ANSIStyler.rtOrange.r, g: ANSIStyler.rtOrange.g, b: ANSIStyler.rtOrange.b))

print("\n=== End Test ===\n")
