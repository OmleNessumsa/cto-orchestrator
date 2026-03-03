# ADR-004: Claude Events to Kanban Board Bridge Architecture

## Status
Accepted

## Context
RT-026 requires connecting Claude tool usage events (particularly `TodoWrite`) to the Kanban board for automatic card management. When Claude creates/updates todos, moves tasks, or spawns sub-agents, the Kanban board should reflect these changes in real-time.

Key requirements:
1. TodoWrite events create/update Kanban cards
2. Task completion moves cards to Done column
3. Sub-agent activity creates agent-specific columns (already handled by AgentColumnsManager)
4. Board updates in real-time via existing reactive pipeline
5. No duplicate cards created for same todo item
6. Manual user changes to board are preserved (not overwritten)

This builds on:
- ADR-001: ClaudeOutputParser emits ClaudeToolEvent
- ADR-002: KanbanBoard/Card/Column data model
- ADR-003: AgentColumn visualization

## Decision

### Architecture Overview

```
ClaudeOutputParser
        │
        │ eventPublisher
        ▼
KanbanEventBridge (NEW)
        │
        ├── Subscribes to ClaudeToolEvent stream
        ├── Parses TodoWrite payloads to extract todo items
        ├── Maps todos to KanbanCard operations (create/update/move)
        ├── Handles duplicate detection via content hash
        └── Preserves manual changes via source tracking
        │
        ▼
KanbanBoard
        │
        └── @Published columns ──▶ SwiftUI Views
```

### Core Components

#### 1. TodoItem (Parsed from TodoWrite)
Structured representation of a todo item from Claude's TodoWrite output.

```swift
struct TodoItem: Identifiable, Equatable {
    let id: UUID
    let content: String              // Task description
    let status: TodoStatus           // pending/in_progress/completed
    let activeForm: String           // Present continuous form ("Running tests")
    let sourceHash: String           // Hash for duplicate detection
    let timestamp: Date

    enum TodoStatus: String, Codable {
        case pending
        case inProgress = "in_progress"
        case completed

        /// Map to KanbanCard status
        var cardStatus: CardStatus {
            switch self {
            case .pending: return .backlog
            case .inProgress: return .inProgress
            case .completed: return .done
            }
        }
    }
}
```

#### 2. TodoWritePayload (Parser Output)
Full payload from a TodoWrite event containing all todo items.

```swift
struct TodoWritePayload: Equatable {
    let todos: [TodoItem]
    let timestamp: Date
    let agentId: UUID?

    /// Parse from raw TodoWrite output
    static func parse(from rawOutput: String) -> TodoWritePayload?
}
```

#### 3. CardSource (Tracking Card Origin)
Tracks whether a card was created manually or from Claude events.

```swift
enum CardSource: Codable, Equatable {
    case manual                           // User created via UI
    case claude(sourceHash: String)       // Created from TodoWrite
    case ticket(ref: String)              // Imported from ticket system

    var isManual: Bool {
        if case .manual = self { return true }
        return false
    }
}
```

#### 4. KanbanCard Extension
Add source tracking to existing card model.

```swift
extension KanbanCard {
    /// Source of this card (for change preservation)
    var source: CardSource

    /// Create card from TodoItem
    static func from(_ todo: TodoItem, agentId: UUID?) -> KanbanCard

    /// Check if card matches a todo item
    func matches(_ todo: TodoItem) -> Bool
}
```

#### 5. KanbanEventBridge (Core Orchestrator)
Main component that bridges Claude events to Kanban updates.

```swift
protocol KanbanEventBridgeDelegate: AnyObject {
    func bridge(_ bridge: KanbanEventBridge, didCreateCard card: KanbanCard)
    func bridge(_ bridge: KanbanEventBridge, didUpdateCard card: KanbanCard)
    func bridge(_ bridge: KanbanEventBridge, didMoveCard cardId: UUID, from: CardStatus, to: CardStatus)
}

final class KanbanEventBridge: ObservableObject {
    // Configuration
    weak var delegate: KanbanEventBridgeDelegate?
    var board: KanbanBoard

    // Internal state
    private var knownHashes: Set<String>           // Track processed todos
    private var hashToCardId: [String: UUID]       // Map hash -> card for updates
    private var cancellables = Set<AnyCancellable>()

    // Initialization
    init(board: KanbanBoard)

    // Subscription
    func subscribe(to parser: ClaudeOutputParser)
    func unsubscribe()

    // Event handling
    func handleEvent(_ event: ClaudeToolEvent)

    // Manual operations (preserve user intent)
    func markAsManual(_ cardId: UUID)
}
```

### Event Flow

#### TodoWrite Event Processing

```
ClaudeToolEvent (toolType: .todoWrite, rawOutput: "...")
        │
        ▼
KanbanEventBridge.handleEvent()
        │
        ├── 1. Parse rawOutput to TodoWritePayload
        │
        ├── 2. For each TodoItem in payload:
        │       │
        │       ├── Calculate sourceHash
        │       │
        │       ├── Check if hash exists in knownHashes
        │       │       │
        │       │       ├── [NO] ──▶ Create new KanbanCard
        │       │       │            Add to board.backlogColumn
        │       │       │            Store hash → cardId mapping
        │       │       │
        │       │       └── [YES] ─▶ Lookup cardId from mapping
        │       │                    Check if card.source.isManual
        │       │                    │
        │       │                    ├── [Manual] Skip update (preserve)
        │       │                    │
        │       │                    └── [Claude] Update status if changed
        │       │                               Move card if status changed
        │       │
        │       └── Update knownHashes
        │
        └── 3. Emit delegate callbacks
```

#### Status Change Handling

```swift
// When todo status changes from pending → in_progress
board.moveCard(cardId, from: backlogColumn, to: inProgressColumn)

// When todo status changes to completed
board.moveCard(cardId, from: currentColumn, to: doneColumn)
let updatedCard = card.withStatus(.done)
board.updateCard(updatedCard, in: doneColumn.id)
```

### Duplicate Detection Strategy

**Content Hashing:**
```swift
extension TodoItem {
    /// Generate deterministic hash for duplicate detection
    var sourceHash: String {
        // Use content + activeForm to create stable identifier
        // Status is NOT included (same task can change status)
        let input = "\(content.lowercased().trimmingCharacters(in: .whitespaces))"
        return SHA256.hash(input).prefix(16)
    }
}
```

**Why content-based hashing:**
- TodoWrite events include full todo list each time (not deltas)
- Same task appears multiple times with different statuses
- We need stable identifier that survives status changes
- Content string is the most stable identifier

### Manual Change Preservation

**Rules:**
1. Cards with `source: .manual` are NEVER modified by bridge
2. Cards with `source: .claude(hash)` can be updated if hash matches
3. User can "claim" a Claude-created card (converts to manual)
4. Moving a card manually doesn't change source, but blocks auto-move

**Implementation:**
```swift
extension KanbanEventBridge {
    private var manuallyMovedCards: Set<UUID>  // Cards user has moved

    func handleCardMoved(by user: UUID) {
        manuallyMovedCards.insert(cardId)
        // Card will no longer auto-move, but can still update title/desc
    }

    func shouldUpdateCard(_ cardId: UUID, for todo: TodoItem) -> Bool {
        guard let card = board.findCard(id: cardId)?.card else { return false }

        // Never update manual cards
        if card.source.isManual { return false }

        // Don't move cards user has touched
        if manuallyMovedCards.contains(cardId) && card.status != todo.status.cardStatus {
            return false  // Skip status update, but allow other updates
        }

        return true
    }
}
```

### Sub-Agent Activity Integration

Sub-agent spawning is already handled by `AgentColumnsManager`. The bridge integrates:

```swift
extension KanbanEventBridge {
    func handleTaskEvent(_ event: ClaudeToolEvent) {
        guard case .task(let description, let agentType) = event.toolType else { return }

        // Create card for the sub-agent task if it doesn't exist
        let hash = hashForTask(description, agentType)

        if !knownHashes.contains(hash) {
            let card = KanbanCard(
                title: description,
                description: "Sub-agent task: \(agentType ?? "general")",
                status: .inProgress,
                labels: [.subAgent],
                assignee: event.agentId?.uuidString
            )
            card.source = .claude(sourceHash: hash)

            let inProgressColumn = board.columns.first { $0.title == "In Progress" }
            board.addCard(card, to: inProgressColumn?.id ?? board.columns[1].id)
        }

        // Track for completion
        if let agentId = event.agentId {
            agentTaskCards[agentId] = card.id
        }
    }

    func handleTaskCompleted(_ event: ClaudeToolEvent) {
        // Move associated card to Done
        if let cardId = agentTaskCards[event.id] {
            moveCardToDone(cardId)
        }
    }
}
```

### Real-Time Update Pipeline

The bridge uses Combine to maintain real-time sync:

```swift
extension KanbanEventBridge {
    func subscribe(to parser: ClaudeOutputParser) {
        parser.eventPublisher
            .filter { $0.toolType == .todoWrite || $0.toolType.isTask }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }
}
```

## Thread Safety

- **KanbanEventBridge**: Processes events on main thread (parser delivers there)
- **KanbanBoard**: Already thread-safe with internal dispatch queue
- **Hash lookups**: Dictionary operations are main-thread only
- **No race conditions**: Single-threaded event processing

## Consequences

### Positive
- Automatic card creation from Claude todos
- Real-time board updates as Claude works
- Manual changes preserved (no overwrites)
- Clean integration with existing parser/board
- Duplicate prevention via content hashing
- Sub-agent tasks visible on board

### Negative
- Additional memory for hash tracking
- Full todo list parsed on each TodoWrite (no deltas)
- Content changes to same task create new cards

### Mitigations
- Hash storage is O(n) where n = total unique todos (bounded)
- Full parsing is fast (JSON-like structure)
- Consider edit distance for content change detection (future)

## File Organization

```
RickTerminal/Claude/
├── ClaudeToolEvent.swift       # Existing - add extension
├── ClaudeOutputParser.swift    # Existing - no changes
├── TodoWriteParser.swift       # NEW - parse TodoWrite payload
└── KanbanEventBridge.swift     # NEW - main bridge component

RickTerminal/Kanban/
├── KanbanCard.swift            # Existing - add source property
├── CardSource.swift            # NEW - source tracking enum
└── ... (existing files)
```

## API Summary

### KanbanEventBridge

```swift
// Initialize
let bridge = KanbanEventBridge(board: kanbanBoard)
bridge.delegate = self

// Connect to parser
bridge.subscribe(to: outputParser)

// Manual card claiming
bridge.markAsManual(cardId)

// Check card source
if let card = board.findCard(id: cardId)?.card {
    if card.source.isManual {
        // User created or claimed this card
    }
}
```

### Integration Example

```swift
class SessionCoordinator: KanbanEventBridgeDelegate {
    let parser: ClaudeOutputParser
    let board: KanbanBoard
    let bridge: KanbanEventBridge
    let agentManager: AgentColumnsManager

    init(session: ShellSession) {
        self.parser = ClaudeOutputParser(sessionId: session.id)
        self.board = KanbanBoard.standard(projectRef: session.workingDirectory)
        self.bridge = KanbanEventBridge(board: board)
        self.agentManager = AgentColumnsManager()

        bridge.delegate = self
        bridge.subscribe(to: parser)
        agentManager.subscribe(to: parser)
    }

    // Delegate methods
    func bridge(_ bridge: KanbanEventBridge, didCreateCard card: KanbanCard) {
        // Optional: Show notification
    }

    func bridge(_ bridge: KanbanEventBridge, didMoveCard cardId: UUID, from: CardStatus, to: CardStatus) {
        // Optional: Animate transition
    }
}
```

## References
- RT-026: Connect Claude Events to Kanban Updates
- RT-004: EPIC: Live Kanban Board & Agent Visualization
- ADR-001: Claude Tool Usage Parsing Architecture
- ADR-002: Kanban Board Data Model Architecture
- ADR-003: Agent Column Visualization Architecture
