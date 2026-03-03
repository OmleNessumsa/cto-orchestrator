# Implementation: RT-022 - Kanban Board Data Model

## Summary
Built the complete data model layer for the Kanban board system, following existing project conventions from `ClaudeToolEvent.swift` and `ShellSession.swift`.

## Files Created

### Architecture Decision Record
- `docs/adr/ADR-002-kanban-board-data-model.md` - Documents design decisions for the data model architecture

### Data Models
- `RickTerminal/Kanban/KanbanCard.swift` - Card struct with all properties (title, description, status, labels, priority, timestamps, assignee, ticketRef)
- `RickTerminal/Kanban/KanbanColumn.swift` - Column struct containing cards array with WIP limits
- `RickTerminal/Kanban/KanbanBoard.swift` - Observable board class with thread-safe updates and Codable bridging

## Key Design Decisions

### 1. Struct vs Class Pattern
- **KanbanCard** and **KanbanColumn** are value-type structs (Codable, Equatable, copy-on-write)
- **KanbanBoard** is a reference-type class with `@Published` for SwiftUI reactivity

### 2. Thread Safety
- Serial `DispatchQueue` per board for atomic mutations
- All mutations happen on background queue
- UI updates dispatched to main thread via `DispatchQueue.main.async`

### 3. Codable Persistence
- `CodableBoard` struct wraps `KanbanBoard` for JSON serialization
- ISO8601 date encoding for JSON compatibility
- `save(to:)` and `load(from:)` convenience methods

### 4. Observable Events
- `@Published var columns` triggers SwiftUI view updates
- `cardEvents` Combine publisher for fine-grained event streaming (added, removed, moved, updated)

## Model Properties

### KanbanCard
```swift
- id: UUID
- title: String
- description: String
- status: CardStatus (.backlog, .inProgress, .review, .done, .blocked)
- labels: [CardLabel]
- priority: CardPriority (.low, .medium, .high, .critical)
- createdAt: Date
- updatedAt: Date
- dueDate: Date?
- assignee: String?
- ticketRef: String?
- estimatedPoints: Int?
- completedAt: Date?
```

### KanbanColumn
```swift
- id: UUID
- title: String
- cards: [KanbanCard]
- limit: Int? (WIP limit)
- color: String? (hex)
- order: Int
- isCollapsed: Bool
```

### KanbanBoard
```swift
- id: UUID
- title: String
- columns: [KanbanColumn] (@Published)
- createdAt: Date
- updatedAt: Date
- projectRef: String?
```

## Acceptance Criteria Checklist

- [x] Board model with columns array
- [x] Column model with cards array
- [x] Card model with all needed properties (title, description, status, labels, timestamps)
- [x] Models are Codable for JSON persistence
- [x] Observable/Published for SwiftUI binding
- [x] Thread-safe updates (serial queue pattern)

## Integration Points

1. **Agent Assignment**: Cards have `assignee` field for agent IDs
2. **Ticket References**: `ticketRef` links to external tickets (e.g., "RT-022")
3. **Status Tracking**: Card events stream via Combine for real-time UI updates
4. **Persistence**: JSON save/load for session continuity
