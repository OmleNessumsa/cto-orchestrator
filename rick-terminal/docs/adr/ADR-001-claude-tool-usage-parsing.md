# ADR-001: Claude Tool Usage Parsing Architecture

## Status
Accepted

## Context
RT-020 requires parsing Claude CLI output to detect tool usage events (file reads, writes, bash commands, etc.) and emit status updates for the agent columns UI. This is the bridge between Claude working and the UI showing what's happening.

The existing `ShellSession` class accumulates raw output as a string. We need to:
1. Intercept Claude CLI output as it streams
2. Parse tool invocation patterns from the output
3. Emit structured events via Combine publishers
4. Track file operations and command executions with their status

## Decision

### Architecture Overview

```
ShellSession.output (String)
       │
       ▼
ClaudeOutputParser (stateful parser)
       │
       ├── Detects tool start/completion patterns
       ├── Maintains parsing state (buffering partial output)
       └── Emits ClaudeToolEvent via Combine
       │
       ▼
AgentStatusPublisher (aggregates per-agent)
       │
       ├── Tracks current operation per agent
       ├── Maintains operation history
       └── Publishes AgentStatus updates
       │
       ▼
UI Agent Columns (subscribes to status)
```

### Key Components

#### 1. ClaudeToolEvent (Data Model)
Structured representation of a tool usage event parsed from Claude output.

```swift
enum ClaudeToolType {
    case read(path: String)
    case write(path: String)
    case edit(path: String)
    case bash(command: String)
    case glob(pattern: String)
    case grep(pattern: String, path: String?)
    case webFetch(url: String)
    case webSearch(query: String)
    case task(description: String)
    case todoWrite
    case askUser(question: String)
    case unknown(name: String)
}

enum ClaudeToolStatus {
    case started
    case completed(result: ToolResult)
    case failed(error: String)
}

struct ClaudeToolEvent {
    let id: UUID
    let timestamp: Date
    let toolType: ClaudeToolType
    let status: ClaudeToolStatus
    let agentId: UUID?  // For multi-agent scenarios
}
```

#### 2. ClaudeOutputParser (Parser)
Stateful parser that processes output chunks and emits events.

```swift
protocol ClaudeOutputParserDelegate: AnyObject {
    func parser(_ parser: ClaudeOutputParser, didEmit event: ClaudeToolEvent)
}

class ClaudeOutputParser {
    weak var delegate: ClaudeOutputParserDelegate?

    // Combine publisher for reactive integration
    var eventPublisher: AnyPublisher<ClaudeToolEvent, Never>

    // Process incremental output
    func process(_ chunk: String)

    // Reset parser state
    func reset()
}
```

#### 3. AgentStatusPublisher (Aggregator)
Aggregates tool events into agent-level status for UI consumption.

```swift
struct AgentStatus {
    let agentId: UUID
    let currentOperation: ClaudeToolType?
    let operationStatus: ClaudeToolStatus?
    let recentOperations: [ClaudeToolEvent]
    let filesModified: [String]
    let commandsRun: Int
}

class AgentStatusPublisher: ObservableObject {
    @Published var statuses: [UUID: AgentStatus]

    // Subscribe to parser events
    func connect(to parser: ClaudeOutputParser)
}
```

### Parsing Strategy

Claude CLI output follows predictable patterns for tool usage:

```
⏺ Read(file_path: "/path/to/file.swift")
  [file contents or result]

⏺ Bash(command: "npm test")
  [command output]

⏺ Write(file_path: "/path/to/new-file.ts")
  [file contents being written]
```

The parser will:
1. **Line-based detection**: Scan for `⏺` (or `●`) markers indicating tool start
2. **Pattern matching**: Use regex to extract tool name and parameters
3. **State tracking**: Buffer output until tool completion
4. **Completion detection**: Recognize when a tool result ends (next tool start, end of output, or timeout)

### Integration Points

1. **ShellSession Extension**
   - Add optional `ClaudeOutputParser` to ShellSession
   - Hook into `readOutput()` to feed chunks to parser
   - Expose `toolEventPublisher` for consumers

2. **ContentView Integration**
   - Subscribe to `AgentStatusPublisher.statuses`
   - Display current operation in agent column

3. **Future: Multi-Agent Support**
   - Parser can detect agent switching patterns
   - Events tagged with agent ID for proper attribution

## Consequences

### Positive
- Clean separation between parsing and UI
- Combine-native integration matches existing patterns
- Stateful parsing handles streaming output correctly
- Extensible for new tool types
- Testable in isolation

### Negative
- Parsing relies on Claude CLI output format (may change)
- Additional memory for buffering partial output
- Slight latency between output and parsed event

### Mitigations
- Abstract parsing patterns behind protocol for easy updates
- Configurable buffer limits to prevent memory issues
- Unit tests against known output samples

## Implementation Notes

### File Organization
```
RickTerminal/Claude/
├── ClaudeToolEvent.swift      # Data models
├── ClaudeOutputParser.swift   # Parser implementation
├── AgentStatusPublisher.swift # Status aggregation
└── ClaudeToolPatterns.swift   # Regex patterns (private)
```

### Thread Safety
- Parser processes on background queue (outputQueue)
- Events published to main thread for UI
- Use `PassthroughSubject` for thread-safe event emission

### Testing Strategy
- Unit tests with captured Claude output samples
- Property-based tests for parser state machine
- Integration tests with mock ShellSession

## References
- RT-020: Parse Claude Tool Usage for Status Updates
- RT-003: EPIC: Claude CLI Integration
- Existing: ShellSession.swift, ShellSessionManager.swift
