# Claude Output Styling System

This directory contains the components for visually distinguishing and styling Claude CLI output within Rick Terminal.

## Architecture

The Claude output styling system consists of several coordinated components:

### 1. Output Detection (`ClaudeOutputDetector.swift`)

Monitors terminal output stream and detects Claude-specific patterns:
- Claude prompts (`claude>` or `claude$`)
- Tool invocations (lines starting with `⏺` or `●`)
- Thinking blocks (`<thinking>...</thinking>`)
- Response boundaries

Emits events:
- `claudeResponseStart` - Claude begins responding
- `claudeResponseChunk(String)` - Chunk of Claude's response
- `claudeResponseEnd` - Response complete
- `toolInvocation(String)` - Tool being executed
- `regularOutput(String)` - Normal terminal output

### 2. ANSI Styling (`ANSIStyler.swift`)

Applies ANSI escape codes for terminal-native styling:
- RGB color support for Rick Terminal theme colors
- Foreground/background coloring
- Text styles (bold, italic, underline, dim)
- Special methods for Claude-specific elements:
  - `claudeResponse()` - Adds purple left border
  - `codeBlock()` - Styles code with green + language label
  - `inlineCode()` - Green mono text
  - `header()` - Bold + purple accent
  - `toolInvocation()` - Purple highlighting
  - `error()` - Orange warning color
  - `markdown()` - Converts markdown to ANSI

### 3. Output Formatting (`ClaudeOutputFormatter.swift`)

High-level formatter that combines detection + styling:
- Processes markdown syntax
- Applies code block highlighting
- Adds visual distinction (left border)
- Supports streaming with `StreamFormatter` for line-by-line processing

### 4. Markdown Rendering (`MarkdownRenderer.swift`)

NSAttributedString-based markdown renderer (for future rich text support):
- Headers (h1-h6)
- Bold, italic, inline code
- Code blocks with syntax highlighting
- Lists (ordered/unordered)
- Blockquotes
- Links

**Note:** Currently not used in terminal output (ANSI codes used instead), but available for overlay UI or inspector panels.

### 5. Output Styling (`ClaudeOutputStyler.swift`)

Orchestrates detection and formatting for Claude responses:
- Buffers streaming output
- Detects response boundaries
- Applies styling via markdown renderer
- Produces `StyledOutput` with attributed text

**Note:** Built for NSAttributedString rendering; consider using `ClaudeOutputFormatter` for terminal ANSI output instead.

## Usage

### Basic Formatting

```swift
let formatter = ClaudeOutputFormatter()

// Format complete response
let claudeResponse = "Here's how to **solve** this:\n```swift\nprint(\"Hello\")\n```"
let styled = formatter.format(claudeResponse)
print(styled) // Output with ANSI codes for purple border, green code, etc.
```

### Streaming Output

```swift
let streamFormatter = ClaudeOutputFormatter.StreamFormatter()

// Process chunks as they arrive
if let formatted = streamFormatter.process("First line\n") {
    terminal.send(formatted)
}

if let formatted = streamFormatter.process("Second line\n") {
    terminal.send(formatted)
}

// Flush remaining buffer
if let formatted = streamFormatter.flush() {
    terminal.send(formatted)
}
```

### Detection Only

```swift
let detector = ClaudeOutputDetector()

detector.eventPublisher
    .sink { event in
        switch event {
        case .claudeResponseStart:
            print("Claude is responding...")
        case .claudeResponseChunk(let text):
            print("Claude: \(text)")
        case .claudeResponseEnd:
            print("Response complete")
        default:
            break
        }
    }
    .store(in: &cancellables)

detector.process(terminalOutput)
```

## Integration with Terminal

Currently integrated in `RickTerminalViewController`:

1. Terminal output is fed to `ClaudeOutputDetector` via `feed(byteArray:)` override
2. Detector emits events tracked in `handleClaudeOutputEvent()`
3. Response buffer accumulates chunks

### Future Enhancements

For full styling integration:

**Option A: ANSI Wrapper Script**
Create a wrapper script that pipes `claude` command through formatter:
```bash
claude | rick-claude-formatter
```

**Option B: PTY Interception**
Intercept PTY output before SwiftTerm, apply ANSI codes, then feed to terminal.

**Option C: Overlay Rendering**
Render styled NSAttributedString overlay on top of terminal view for Claude responses.

## Visual Design

Claude responses are visually distinct with:
- **Left Border**: Purple (`#7B78AA`) vertical bar `▎`
- **Code Blocks**: Green text (`#7FFC50`) with language label
- **Headers**: Bold with purple accent
- **Tool Invocations**: Purple highlighting
- **Errors**: Orange (`#FF9F40`) color
- **Inline Code**: Green monospace

## Color Reference

From `Color+Theme.swift`:
- `rtPurple`: `#7B78AA` (123, 120, 170)
- `rtGreen`: `#7FFC50` (127, 252, 80)
- `rtOrange`: `#FF9F40` (255, 159, 64)
- `rtBackgroundSecondary`: `#1E3738` (30, 55, 56)
- `rtMuted`: `#464467` (70, 68, 103)

## Testing

Test Claude output styling:

```bash
# In Rick Terminal, launch Claude
claude

# Claude's responses should now have:
# - Purple left border (▎)
# - Syntax-highlighted code blocks
# - Styled markdown (bold, italic, headers)
# - Green inline code
```

## Dependencies

- **SwiftTerm**: Terminal emulation (supports ANSI codes natively)
- **Combine**: Event streaming for detection
- **AppKit**: NSAttributedString for rich text (MarkdownRenderer)

## Files

- `ClaudeOutputDetector.swift` - Pattern detection & event emission
- `ClaudeOutputFormatter.swift` - High-level formatting API
- `ANSIStyler.swift` - ANSI escape code utilities
- `MarkdownRenderer.swift` - NSAttributedString markdown rendering
- `ClaudeOutputStyler.swift` - Attributed string styling (legacy)
- `ClaudeOutputParser.swift` - Tool usage parsing (separate concern)
- `ClaudeToolEvent.swift` - Tool event data model
- `KanbanEventBridge.swift` - Kanban board integration
- `TodoWriteParser.swift` - Todo list parsing
- `ClaudePathDetector.swift` - File path detection

## See Also

- [ADR-001: Claude Tool Usage Parsing](../../docs/adr/ADR-001-claude-tool-usage-parsing.md)
- [ADR-004: Claude Kanban Event Bridge](../../docs/adr/ADR-004-claude-kanban-event-bridge.md)
- [Claude CLI Configuration Guide](../../docs/CLAUDE_CLI_CONFIGURATION.md)
