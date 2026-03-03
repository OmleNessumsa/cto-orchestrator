# ADR-003: Agent Column Visualization Architecture

## Status
Accepted

## Context
RT-025 requires a real-time visualization system for active sub-agents (Morty's) spawned by the Claude CLI. Each agent should appear as a column showing:
- Agent name/role
- Current task being performed
- Recent action log
- Status indicator (working/idle/done)
- Smooth appear/disappear animations as agents spawn/complete

This builds on the existing `ClaudeToolEvent` and `ClaudeOutputParser` infrastructure (ADR-001) and complements the Kanban board data model (ADR-002).

## Decision

### Data Model Architecture

```
AgentColumnsManager (1) ──┬── AgentColumn (n) ──┬── AgentAction (n)
                          │                      │
                          └── Event Subscriptions └── Status, Timestamps
```

### Core Models

#### 1. AgentColumn (Observable State)
Represents a single active agent's visualization column.

```swift
class AgentColumn: Identifiable, ObservableObject {
    let id: UUID                          // Matches agentId from ClaudeToolEvent
    var role: AgentRole                   // Agent type/role
    @Published var displayName: String    // Human-readable name
    @Published var currentTask: String?   // Active task description
    @Published var status: AgentStatus    // working/idle/done/error
    @Published var actions: [AgentAction] // Recent action log (capped)
    var spawnedAt: Date
    var completedAt: Date?

    // Lifecycle flags for UI animations
    @Published var isAppearing: Bool
    @Published var isDisappearing: Bool
}
```

#### 2. AgentRole (Type Classification)
Enum categorizing agent types based on Task tool's `subagent_type`.

```swift
enum AgentRole: String, Codable, CaseIterable {
    case architect = "architect"
    case backend = "backend"
    case frontend = "frontend"
    case explorer = "Explore"
    case planner = "Plan"
    case generalPurpose = "general-purpose"
    case bash = "Bash"
    case unknown = "unknown"

    var displayName: String
    var iconName: String      // SF Symbol
    var themeColor: Color     // Role-specific accent color
}
```

#### 3. AgentStatus (Lifecycle State)
```swift
enum AgentStatus: String, CaseIterable {
    case spawning        // Just created, appearing animation
    case working         // Actively executing tools
    case idle           // Waiting between actions
    case done           // Completed successfully
    case error          // Failed with error
}
```

#### 4. AgentAction (Log Entry)
Individual action log entry for the scrolling activity feed.

```swift
struct AgentAction: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let toolType: ClaudeToolType
    let description: String
    let status: ActionStatus     // started/completed/failed

    enum ActionStatus: String {
        case started
        case completed
        case failed
    }
}
```

#### 5. AgentColumnsManager (Orchestrator)
Observable manager that bridges `ClaudeOutputParser` events to column state.

```swift
class AgentColumnsManager: ObservableObject {
    @Published private(set) var columns: [AgentColumn]
    private var columnsByAgent: [UUID: AgentColumn]
    private var cancellables = Set<AnyCancellable>()

    // Configuration
    var maxActionsPerColumn: Int = 50
    var columnFadeDelay: TimeInterval = 2.0

    // Methods
    func subscribe(to parser: ClaudeOutputParser)
    func handleEvent(_ event: ClaudeToolEvent)
    func columnForAgent(_ agentId: UUID) -> AgentColumn?
    func dismissColumn(_ columnId: UUID)
}
```

### Event Flow

```
ClaudeOutputParser
        │
        │ eventPublisher
        ▼
AgentColumnsManager
        │
        │ subscribe(to:)
        ▼
   handleEvent()
        │
        ├─[Task tool started]──▶ createColumn() ──▶ @Published columns
        │
        ├─[Other tool events]──▶ updateColumn() ──▶ AgentColumn.actions
        │
        └─[Task completed]─────▶ markComplete() ──▶ fade out animation
```

### Column Lifecycle

1. **Spawn Detection**: When `ClaudeToolEvent` with `toolType == .task` is received, extract `agentId` and create new `AgentColumn`
2. **Activity Tracking**: Route subsequent events matching `agentId` to column's action log
3. **Status Updates**: Update status based on event flow (working when executing, idle between)
4. **Completion**: When task completes (success/error), set `status = .done/.error`, trigger fade animation
5. **Cleanup**: Remove column from array after fade animation completes

### UI Components

#### AgentColumnView
```swift
struct AgentColumnView: View {
    @ObservedObject var column: AgentColumn

    // Layout:
    // ┌─────────────────────┐
    // │ [icon] Role Name    │  <- Header with role icon/color
    // │ Status: ● working   │  <- Status indicator
    // ├─────────────────────┤
    // │ Current Task:       │  <- Current task section
    // │ "Implementing..."   │
    // ├─────────────────────┤
    // │ Recent Actions:     │  <- Scrolling log
    // │ • Read file.swift   │
    // │ • Edit code.swift   │
    // │ • Bash npm test     │
    // └─────────────────────┘
}
```

#### AgentColumnsContainer
```swift
struct AgentColumnsContainer: View {
    @ObservedObject var manager: AgentColumnsManager

    // Horizontal scrolling container
    // Animates column appear/disappear
    // Can be placed below terminal output or as overlay
}
```

### Thread Safety

- **AgentColumnsManager**: Processes events on main thread (via parser's delegate dispatch)
- **AgentColumn**: `@Published` properties ensure UI updates on main thread
- **Action Log**: Capped array prevents unbounded growth

### Integration with Existing Code

1. **ClaudeToolEvent.agentId**: Already supports agent tracking (nullable UUID)
2. **ClaudeOutputParser**: Already emits events with agentId when present
3. **RickTheme**: Use existing color system (`rtAccentPurple`, `rtAccentGreen`, etc.)
4. **AgentStatus in ClaudeToolEvent.swift**: Reuse patterns but create dedicated UI type

### Animation Strategy

- **Appear**: SlideIn + FadeIn (0.3s) when column created
- **Disappear**: FadeOut (0.5s) after `columnFadeDelay` when done
- **Status Pulse**: Subtle pulse animation on status indicator when working
- **Action Entry**: Quick slide-in for new log entries

## Consequences

### Positive
- Real-time visibility into agent activity
- Clean separation: manager handles events, views handle presentation
- Reuses existing event infrastructure
- Bounded memory with capped action logs
- Smooth animations prevent jarring UI changes

### Negative
- Additional memory per active agent column
- Animation timing requires tuning
- Agent ID must be correctly propagated through parser

### Mitigations
- Cap action log size (50 entries default)
- Make animation durations configurable
- Parser already handles agentId extraction

## File Organization

```
RickTerminal/Agent/
├── AgentColumn.swift          # AgentColumn class + AgentAction struct
├── AgentRole.swift            # Role enum with display properties
├── AgentStatus.swift          # Status enum with UI properties
├── AgentColumnsManager.swift  # Event-to-column orchestrator
└── Views/
    ├── AgentColumnView.swift      # Single column view
    └── AgentColumnsContainer.swift # Container with animations
```

## References
- RT-025: Implement Agent Column Visualization
- RT-004: EPIC: Live Kanban Board & Agent Visualization
- ADR-001: Claude Tool Usage Parsing Architecture
- ADR-002: Kanban Board Data Model Architecture
