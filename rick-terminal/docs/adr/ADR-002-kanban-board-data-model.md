# ADR-002: Kanban Board Data Model Architecture

## Status
Accepted

## Context
RT-022 requires data models for a Kanban board that will visualize agent tasks and workflow states. The board needs to support:
- Multiple boards (e.g., per-project or per-session)
- Columns representing workflow stages (Backlog, In Progress, Done, etc.)
- Cards representing individual tasks/tickets
- Real-time updates as agents work
- Persistence to JSON for session continuity
- Thread-safe updates from background queues

This integrates with the existing agent visualization system (RT-004 epic) and follows patterns established in `ClaudeToolEvent.swift` and `ShellSession.swift`.

## Decision

### Data Model Hierarchy

```
Board (1) ──┬── Column (n) ──┬── Card (n)
            │                │
            └── Settings     └── Labels, Timestamps, Status
```

### Core Models

#### 1. KanbanCard (Leaf Node)
Represents a single task/ticket on the board.

```swift
struct KanbanCard: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var status: CardStatus
    var labels: [CardLabel]
    var priority: CardPriority
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var assignee: String?  // Agent ID or name
    var ticketRef: String? // External ticket reference (e.g., "RT-022")
}

enum CardStatus: String, Codable, CaseIterable {
    case backlog
    case inProgress
    case review
    case done
    case blocked
}

enum CardPriority: Int, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

struct CardLabel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String  // Hex color code
}
```

#### 2. KanbanColumn (Container)
Groups cards by workflow stage.

```swift
struct KanbanColumn: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var cards: [KanbanCard]
    var limit: Int?  // WIP limit
    var color: String?  // Optional column color
    var order: Int
}
```

#### 3. KanbanBoard (Root)
Top-level container with observable state.

```swift
class KanbanBoard: Identifiable, ObservableObject {
    let id: UUID
    var title: String
    @Published var columns: [KanbanColumn]
    var createdAt: Date
    var updatedAt: Date

    // Thread-safe update queue
    private let updateQueue: DispatchQueue

    // Computed properties for quick access
    var totalCards: Int
    var cardsByStatus: [CardStatus: [KanbanCard]]
}
```

### Observable Pattern

The `KanbanBoard` class uses `ObservableObject` with `@Published` columns to trigger SwiftUI updates. Individual column/card mutations go through board methods that:
1. Dispatch to `updateQueue` for thread safety
2. Mutate the data
3. Publish changes on main thread

```swift
extension KanbanBoard {
    func moveCard(_ cardId: UUID, to columnId: UUID, at index: Int) {
        updateQueue.async { [weak self] in
            // Perform move atomically
            guard let self = self else { return }
            // ... mutation logic ...

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
}
```

### Codable Strategy

Since `KanbanBoard` is a class with `@Published`, we implement a `CodableBoard` struct for persistence:

```swift
struct CodableBoard: Codable {
    let id: UUID
    let title: String
    let columns: [KanbanColumn]
    let createdAt: Date
    let updatedAt: Date
}

extension KanbanBoard {
    func toCodable() -> CodableBoard
    static func from(_ codable: CodableBoard) -> KanbanBoard
}
```

### Thread Safety Approach

- **Single Writer**: All mutations go through `updateQueue` (serial queue)
- **Main Thread Publishing**: UI updates dispatched to main thread
- **Copy-on-Write**: Structs (`KanbanCard`, `KanbanColumn`) are value types
- **Atomic Operations**: Card moves happen as single transactions

### Default Board Configuration

New boards initialize with standard Kanban columns:

```swift
static var defaultColumns: [KanbanColumn] {
    [
        KanbanColumn(id: UUID(), title: "Backlog", cards: [], limit: nil, order: 0),
        KanbanColumn(id: UUID(), title: "In Progress", cards: [], limit: 3, order: 1),
        KanbanColumn(id: UUID(), title: "Review", cards: [], limit: 2, order: 2),
        KanbanColumn(id: UUID(), title: "Done", cards: [], limit: nil, order: 3)
    ]
}
```

## Consequences

### Positive
- Clean separation: structs for data, class for observable state
- Thread-safe updates without blocking UI
- Codable support enables JSON persistence
- Identifiable enables SwiftUI ForEach without extra wrappers
- Extensible label system for categorization
- WIP limits support Kanban best practices

### Negative
- Manual Codable bridging for `KanbanBoard` class
- Additional memory for dispatch queue per board
- No built-in undo/redo (could add later with command pattern)

### Mitigations
- `CodableBoard` wrapper is minimal boilerplate
- Queue is lightweight, boards are few
- Command pattern can be layered on top if needed

## File Organization

```
RickTerminal/Kanban/
├── KanbanCard.swift       # Card struct + enums
├── KanbanColumn.swift     # Column struct
├── KanbanBoard.swift      # Board class + CodableBoard
└── KanbanDefaults.swift   # Default labels, columns
```

## Integration Points

1. **Agent Status**: Cards can reference agent IDs for assignment
2. **Ticket System**: `ticketRef` links to external ticket numbers
3. **Persistence**: `CodableBoard` saves/loads from JSON
4. **UI Binding**: `@ObservedObject var board: KanbanBoard` in views

## References
- RT-022: Build Kanban Board Data Model
- RT-004: EPIC: Live Kanban Board & Agent Visualization
- ADR-001: Claude Tool Usage Parsing Architecture
- Existing patterns: ClaudeToolEvent.swift, ShellSession.swift
