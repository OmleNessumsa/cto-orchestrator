# Claude Output Styling Guide

Visual distinction for Claude CLI output in Rick Terminal using ANSI escape codes, markdown rendering, and syntax highlighting.

## Quick Start

### 1. Add Files to Xcode Project

The following files need to be added to the RickTerminal target:

**Claude Directory** (`RickTerminal/Claude/`):
- `ANSIStyler.swift` - ANSI escape code utilities
- `ClaudeOutputFormatter.swift` - High-level formatting API
- `ClaudeOutputDetector.swift` - Output pattern detection
- `MarkdownRenderer.swift` - NSAttributedString markdown renderer
- `ClaudeOutputStyler.swift` - Attributed string styler
- `ClaudeOutputStyling+Demo.swift` - Demo/test code (DEBUG only)

**How to Add in Xcode:**
1. Right-click on `RickTerminal` group in Project Navigator
2. Select "Add Files to RickTerminal..."
3. Navigate to `RickTerminal/Claude/`
4. Select all `.swift` files (except README.md)
5. Ensure "Copy items if needed" is **unchecked**
6. Ensure "Add to targets: RickTerminal" is **checked**
7. Click "Add"

### 2. Basic Usage

```swift
import Foundation

// Create formatter
let formatter = ClaudeOutputFormatter()

// Format Claude response
let claudeOutput = """
I'll help you with that.

Here's a code example:

```swift
print("Hello!")
```
"""

let styled = formatter.format(claudeOutput)
print(styled)  // Outputs with ANSI codes for purple border + green code
```

### 3. Streaming Output

```swift
let streamFormatter = ClaudeOutputFormatter.StreamFormatter()

// Process chunks as they arrive from Claude
for chunk in streamingOutput {
    if let formatted = streamFormatter.process(chunk) {
        terminal.display(formatted)
    }
}

// Flush remaining content
if let remaining = streamFormatter.flush() {
    terminal.display(remaining)
}
```

## Visual Design

### Color Scheme

Claude responses use Rick Terminal's theme colors:

| Element | Color | RGB | Hex |
|---------|-------|-----|-----|
| Left Border | Purple | (123, 120, 170) | #7B78AA |
| Code Blocks | Green | (127, 252, 80) | #7FFC50 |
| Headers | Purple | (123, 120, 170) | #7B78AA |
| Errors | Orange | (255, 159, 64) | #FF9F40 |
| Comments/Muted | Muted | (70, 68, 103) | #464467 |

### Visual Elements

**Left Border:**
```
▎ This is a Claude response
▎ with a purple left border
▎ for visual distinction
```

**Code Blocks:**
```
▎ [swift]
▎ func example() {
▎     print("Green syntax highlighted code")
▎ }
```

**Markdown:**
- `**Bold**` → ANSI bold
- `*Italic*` → ANSI italic
- `` `code` `` → Green inline code
- `# Headers` → Bold + purple

## Architecture

### Components

```
┌─────────────────────────────────────┐
│      Terminal Output Stream         │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│    ClaudeOutputDetector             │
│  (Monitors stream for patterns)     │
└─────────────┬───────────────────────┘
              │
              ▼ Events (start, chunk, end)
              │
┌─────────────────────────────────────┐
│   ClaudeOutputFormatter             │
│  (Applies ANSI styling)              │
└─────────────┬───────────────────────┘
              │
              ▼ Styled ANSI output
              │
┌─────────────────────────────────────┐
│      SwiftTerm (Renders)            │
└─────────────────────────────────────┘
```

### Detection Patterns

**Claude Prompts:**
- `claude>` or `claude$`

**Tool Invocations:**
- Lines starting with `⏺` or `●`

**Thinking Blocks:**
- `<thinking>...</thinking>`

**Response Boundaries:**
- New prompt appearance
- Shell prompt (`$`, `%`, `#`)

## Integration Examples

### Option 1: Manual Formatting (Current)

Apply formatting explicitly when displaying Claude output:

```swift
// In your view controller or session manager
func displayClaudeResponse(_ text: String) {
    let formatter = ClaudeOutputFormatter()
    let styled = formatter.format(text)
    terminal.send(styled)
}
```

### Option 2: Wrapper Script (Recommended)

Create a wrapper that pipes Claude through formatter:

**`~/.local/bin/claude-styled`:**
```bash
#!/bin/bash
claude "$@" | swift /path/to/rick-terminal/scripts/format-claude-output.swift
```

Then in Terminal Settings, use `claude-styled` instead of `claude`.

### Option 3: PTY Interception (Advanced)

Intercept PTY output in `ShellSessionManager`:

```swift
class ShellSessionManager {
    private let claudeDetector = ClaudeOutputDetector()
    private let formatter = ClaudeOutputFormatter()

    func processOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        // Detect Claude output
        claudeDetector.process(text)

        // Format if it's Claude
        if ClaudeOutputFormatter.looksLikeClaudeResponse(text) {
            let styled = formatter.format(text)
            // Send styled version to terminal
        } else {
            // Send original
        }
    }
}
```

## Testing

### Unit Tests

```swift
func testClaudeResponseFormatting() {
    let formatter = ClaudeOutputFormatter()
    let input = "I'll help with that.\n\n```swift\nprint(\"test\")\n```"
    let output = formatter.format(input)

    // Output should contain ANSI codes
    XCTAssertTrue(output.contains("\u{001B}["))

    // Output should have purple border marker
    XCTAssertTrue(output.contains("▎"))
}
```

### Manual Testing

Run the demo script:

```swift
#if DEBUG
// In your app delegate or debug menu
ClaudeOutputStylingDemo.runAll()
#endif
```

Or use the standalone test script:

```bash
swift scripts/test-claude-styling.swift
```

### Visual Inspection

1. Launch Rick Terminal
2. Start Claude CLI: `claude`
3. Ask Claude a question with code
4. Verify:
   - Purple left border on Claude responses
   - Green syntax highlighting on code blocks
   - Bold/italic markdown rendering
   - Tool invocations highlighted in purple

## API Reference

### ANSIStyler

Static utility for ANSI escape codes:

```swift
// Basic colors
ANSIStyler.colorRGB("Text", r: 127, g: 252, b: 80)

// Styles
ANSIStyler.style("Bold", .bold)
ANSIStyler.styled("Bold + Underline", styles: [.bold, .underline])

// Claude-specific
ANSIStyler.claudeResponse("Response text")
ANSIStyler.codeBlock("code", language: "swift")
ANSIStyler.inlineCode("code")
ANSIStyler.header("Header Text", level: 1)
ANSIStyler.toolInvocation("⏺ Read(...)")
ANSIStyler.error("Error message")
ANSIStyler.markdown("**Bold** and *italic*")

// String extensions
"Hello".ansiForeground(.green)
"Code".asCodeBlock(language: "swift")
"**Bold**".markdownStyled()
```

### ClaudeOutputFormatter

High-level formatting API:

```swift
let formatter = ClaudeOutputFormatter(
    enableBorders: true,
    enableMarkdown: true,
    enableSyntaxHighlighting: true
)

// Format complete response
let styled = formatter.format(claudeResponse)

// Format single line
let styledLine = formatter.formatLine(line, isToolLine: false)

// Format tool invocation
let styledTool = formatter.formatToolLine("⏺ Read(...)")

// Detection helpers
ClaudeOutputFormatter.looksLikeClaudeResponse(text)
ClaudeOutputFormatter.isToolLine(line)
```

### ClaudeOutputDetector

Event-based detection:

```swift
let detector = ClaudeOutputDetector()

detector.eventPublisher
    .sink { event in
        switch event {
        case .claudeResponseStart:
            print("Claude started responding")
        case .claudeResponseChunk(let text):
            print("Chunk: \(text)")
        case .claudeResponseEnd:
            print("Response complete")
        case .toolInvocation(let tool):
            print("Tool: \(tool)")
        case .regularOutput(let text):
            print("Regular: \(text)")
        }
    }
    .store(in: &cancellables)

detector.process(terminalOutput)
detector.flush()
detector.reset()
```

### StreamFormatter

Stateful streaming formatter:

```swift
let stream = ClaudeOutputFormatter.StreamFormatter()

// Process chunks
while let chunk = getNextChunk() {
    if let formatted = stream.process(chunk) {
        display(formatted)
    }
}

// Flush remaining
if let remaining = stream.flush() {
    display(remaining)
}

// Reset for new response
stream.reset()
```

## Troubleshooting

### Colors Not Showing

**Problem:** ANSI codes visible as text
**Solution:** Ensure terminal supports 24-bit color (TrueColor)

```swift
// Test ANSI support
print("\u{001B}[38;2;255;0;0mRed\u{001B}[0m")
// Should display "Red" in red color
```

### Borders Not Aligned

**Problem:** Border `▎` character misaligned
**Solution:** Use monospace font that supports Unicode box-drawing

```swift
terminal.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
```

### Performance Issues

**Problem:** Slow rendering with large responses
**Solution:** Use streaming formatter instead of buffering entire response

```swift
// ❌ Slow - buffers entire response
let all = collectAllOutput()
let styled = formatter.format(all)

// ✅ Fast - processes line by line
let stream = ClaudeOutputFormatter.StreamFormatter()
for chunk in chunks {
    if let styled = stream.process(chunk) {
        display(styled)
    }
}
```

### Detection False Positives

**Problem:** Non-Claude output getting styled
**Solution:** Improve detection heuristics or manually control formatting

```swift
// Only format when explicitly in Claude mode
if isClaudeModeActive {
    let styled = formatter.format(output)
}
```

## Future Enhancements

- [ ] Rich text overlay with NSAttributedString
- [ ] Collapsible code blocks
- [ ] Clickable file paths
- [ ] Copy-to-clipboard buttons
- [ ] Search/filter Claude responses
- [ ] Export to HTML/PDF
- [ ] Custom color themes
- [ ] User preference toggles

## Related Documentation

- [Claude CLI Configuration](CLAUDE_CLI_CONFIGURATION.md)
- [ADR-001: Tool Usage Parsing](adr/ADR-001-claude-tool-usage-parsing.md)
- [Claude Output Styling README](../RickTerminal/Claude/README.md)

## Support

For issues or questions:
1. Check [Claude directory README](../RickTerminal/Claude/README.md)
2. Review implementation summary: `IMPLEMENTATION_RT-019_SUMMARY.md`
3. Run debug demo: `ClaudeOutputStylingDemo.runAll()`
4. File issue on GitHub
