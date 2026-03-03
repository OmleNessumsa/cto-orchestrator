# Kanban Board Integration Guide

## Overview

This guide explains how the Kanban board integrates with Claude CLI to provide real-time task visualization.

## Architecture

### Component Hierarchy

```
MainWindowView
├── LayoutState
├── ShellSessionManager
├── AgentColumnsManager
└── KanbanManager
    ├── KanbanBoard (data model)
    └── KanbanEventBridge (event handler)
```

### Event Flow

1. **Claude CLI** outputs tool usage events
2. **ClaudeOutputParser** parses raw output into `ClaudeToolEvent` objects
3. **TodoWriteParser** extracts structured todo items from TodoWrite events
4. **KanbanEventBridge** receives events and determines actions:
   - Create new cards for new todos
   - Update existing cards when status changes
   - Move cards between columns based on status
   - Track manual changes to prevent overwrites
5. **KanbanBoard** updates the data model thread-safely
6. **KanbanBoardView** renders the UI reactively via Combine

## Card Source Types

### Manual (`.manual`)
- Created by user via UI
- Never auto-updated
- Preserved across all Claude events
- Green badge indicator

### Claude (`.claude(sourceHash)`)
- Created from TodoWrite events
- Auto-updates when TodoWrite status changes
- Can be "claimed" to convert to manual
- Purple badge indicator

### Ticket (`.ticket(ref)`)
- Imported from external ticket system (future)
- Blue badge indicator

### Sub-Agent (`.subAgent(agentId, taskHash)`)
- Created when Task tool spawns sub-agent
- Moves to done when sub-agent completes
- Moves to blocked when sub-agent fails
- Orange badge indicator

## Event Handling Rules

### Duplicate Prevention
Cards are uniquely identified by content hash (SHA256 of normalized title):
- Same content = same hash = update existing card
- Different content = new hash = create new card
- Status changes don't create new cards

### Manual Override Protection
1. User claims a card → `source` becomes `.manual`
2. User manually moves a card → `manuallyMovedCards` set tracks it
3. Future TodoWrite events for that content won't auto-move the card
4. Card title can still update if content changes

### Column Mapping

| TodoStatus | CardStatus | Column |
|------------|-----------|---------|
| `pending` | `backlog` | First column (Backlog) |
| `in_progress` | `inProgress` | Column containing "progress" |
| `completed` | `done` | Last column (Done) |

## Usage Examples

### Example 1: TodoWrite Event

**Claude Output:**
```
todos:
- content: "Implement user authentication"
  status: in_progress
  activeForm: "Implementing user authentication"
- content: "Write unit tests"
  status: pending
  activeForm: "Writing unit tests"
```

**Result:**
1. Two cards created (or updated if they exist)
2. "Implement user authentication" → In Progress column
3. "Write unit tests" → Backlog column
4. Both have purple Claude badge

### Example 2: Sub-Agent Task

**Claude Output:**
```
Task(
  description="Explore codebase architecture",
  agentType="explore"
)
```

**Result:**
1. Card created with title "Explore codebase architecture"
2. Placed in In Progress column
3. Orange Sub-Agent badge
4. When task completes → auto-moves to Done

### Example 3: User Claims Card

**User Action:**
Hovers over auto-generated card → Clicks "Claim" button

**Result:**
1. `card.source` changes from `.claude(hash)` to `.manual`
2. Green Manual badge appears
3. Future TodoWrite events won't update this card
4. User has full control

## API Reference

### KanbanManager

```swift
class KanbanManager: ObservableObject {
    @Published var board: KanbanBoard
    @Published var bridge: KanbanEventBridge

    // Subscribe to parser events
    func subscribe(to parser: ClaudeOutputParser)

    // Claim a card (convert to manual)
    func claimCard(_ cardId: UUID)

    // Add manual card
    func addCard(_ card: KanbanCard, to columnId: UUID)

    // Move card between columns
    func moveCard(_ cardId: UUID, from: UUID, to: UUID)
}
```

### KanbanEventBridge

```swift
class KanbanEventBridge: ObservableObject {
    @Published var cardsCreated: Int
    @Published var cardsUpdated: Int
    @Published var lastSyncAt: Date?

    // Mark card as manually managed
    func markAsManual(_ cardId: UUID)

    // Record manual move to prevent auto-move
    func recordManualMove(_ cardId: UUID)

    // Check if card is manual
    func isManualCard(_ cardId: UUID) -> Bool
}
```

### TodoWriteParser

```swift
class TodoWriteParser {
    // Parse TodoWrite output to structured payload
    func parse(from rawOutput: String, agentId: UUID?) -> TodoWritePayload?

    // Convert imperative to active form
    static func toActiveForm(_ imperative: String) -> String
}
```

## Configuration

### Auto-Created Label

Default label applied to auto-generated cards:
```swift
bridge.autoCreatedLabel = CardLabel(name: "Auto", color: "#9E9E9E")
```

### Sub-Agent Tracking

Enable/disable automatic card creation for sub-agents:
```swift
bridge.trackSubAgentTasks = true  // default
```

## Debugging

### Check Sync Status

View last sync time in board header (top-right):
```
Last sync: 5s ago
```

### View Statistics

Board header shows:
- **Green badge**: Cards created
- **Blue badge**: Cards updated

Footer shows:
- Total cards
- Story points
- Overdue count
- Unassigned count

### Inspect Card Details

Click any card to open details sheet showing:
- Source (manual/auto/agent)
- Full metadata
- Creation/update timestamps
- Option to claim if auto-generated

## Troubleshooting

### Cards Not Updating

**Problem**: TodoWrite events not creating cards

**Check**:
1. Is parser connected? (`connectParsers()` called in `MainWindowView`)
2. Is TodoWrite output parsed correctly? (check `TodoWriteParser.parse()`)
3. Are events being emitted? (check `ClaudeOutputParser.eventPublisher`)

### Duplicate Cards

**Problem**: Same todo creates multiple cards

**Check**:
1. Hash computation is deterministic
2. `knownHashes` set is populated
3. Content normalization is working (lowercase, trim whitespace)

### Manual Changes Overwritten

**Problem**: User moves get undone by auto-updates

**Check**:
1. `recordManualMove()` called when user drags card
2. `manuallyMovedCards` set contains card ID
3. Bridge checks this set before auto-moving

## Best Practices

### For Developers

1. **Always use KanbanManager** instead of directly accessing board/bridge
2. **Subscribe in lifecycle hooks** (onAppear/onChange)
3. **Unsubscribe when view disappears** to prevent leaks
4. **Use Combine** for reactive updates (@Published properties)
5. **Thread-safe** updates via board's internal dispatch queue

### For Users

1. **Claim important cards** to prevent auto-updates
2. **Use manual cards** for user-defined tasks
3. **Let Claude manage** auto-generated cards unless you need control
4. **Check sync status** if updates seem delayed
5. **Use card details** to see full metadata and history

## Performance Notes

- **Hash computation**: O(n) where n = content length
- **Duplicate check**: O(1) set lookup
- **Card updates**: Thread-safe via serial dispatch queue
- **UI updates**: Debounced via Combine on main thread
- **Memory**: Weak references prevent retain cycles

## Future Enhancements

Planned improvements:
1. Persistence to disk (save/load board state)
2. Drag-and-drop card reordering
3. Inline card editing
4. Board templates and presets
5. Export to JSON/CSV
6. Integration with external ticket systems

---

**Last Updated**: 2026-02-15
**Author**: frontend-morty
**Ticket**: RT-026
