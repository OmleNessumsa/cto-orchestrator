# Implementation Summary: RT-027 - Persist Kanban Board State

## Samenvatting
**Status**: completed
**Bestanden gewijzigd**:
- RickTerminal/Kanban/KanbanPersistenceManager.swift (new)
- RickTerminal/Kanban/KanbanManager.swift (modified)
- RickTerminalTests/KanbanPersistenceManagerTests.swift (new)
- RickTerminal.xcodeproj/project.pbxproj (modified)

**Beschrijving**: Implemented complete Kanban board persistence with JSON file storage, debounced auto-save, multi-board support, and graceful corrupted file handling.

**Open vragen**: none

---

## What Was Implemented

### 1. KanbanPersistenceManager (New File)
Created a comprehensive persistence manager at `RickTerminal/Kanban/KanbanPersistenceManager.swift` with the following features:

#### Core Features
- **JSON File Storage**: Boards saved to `~/Library/Application Support/RickTerminal/Boards/`
- **Debounced Auto-Save**: 2-second debounce interval to prevent excessive writes
- **Current Board Tracking**: Remembers the last active board via `current_board.json`
- **Multiple Boards Support**: Each board saved as `{boardId}.json`
- **Atomic Writes**: Uses `.atomic` option to prevent file corruption during writes
- **Thread-Safe**: Uses Combine publishers and dispatch queues for safe concurrent access

#### Public API
```swift
// Save operations
func saveBoard(_ board: KanbanBoard) throws
func saveDebounced(_ board: KanbanBoard)

// Load operations
func loadBoard(_ boardId: UUID) throws -> KanbanBoard
func loadBoardOrDefault(_ boardId: UUID, projectRef: String?) -> KanbanBoard
func loadAllBoards() -> [KanbanBoard]
func loadBoards(forProject projectRef: String) -> [KanbanBoard]

// Current board management
func saveCurrentBoardId(_ boardId: UUID?)
func loadCurrentBoardId() -> UUID?

// Auto-save observation
func observeBoard(_ board: KanbanBoard)
func stopObserving()

// Deletion
func deleteBoard(_ boardId: UUID) throws
func deleteAllBoards() throws
```

#### Corrupted File Handling
- Detects corrupted JSON during load
- Automatically backs up corrupted files to `Boards/Corrupted/` directory
- Returns a new default board when corruption is detected
- Uses custom `PersistenceError` enum for detailed error reporting

### 2. Updated KanbanManager
Modified `RickTerminal/Kanban/KanbanManager.swift` to integrate persistence:

#### Changes Made
- **Auto-Load on Init**: Loads previously saved board or creates new one
- **Auto-Save Integration**: Observes board changes and triggers debounced saves
- **Board Switching**: Added `switchBoard(_:)` method
- **Board Creation**: Added `createNewBoard(title:)` method
- **Project Board Loading**: Added `loadProjectBoards()` method
- **Immediate Save**: Added `saveNow()` for bypassing debounce

#### Init Flow
```swift
init(projectRef: String = "rick-terminal") {
    // 1. Try to load existing board
    if let boardId = persistence.loadCurrentBoardId() {
        board = persistence.loadBoardOrDefault(boardId, projectRef: projectRef)
    } else {
        // 2. Create new board if none exists
        board = KanbanBoard.standard(title: "Rick Terminal Tasks", projectRef: projectRef)
        persistence.saveBoard(board)
        persistence.saveCurrentBoardId(board.id)
    }

    // 3. Start auto-save observation
    persistence.observeBoard(board)
}
```

### 3. Comprehensive Tests
Created `RickTerminalTests/KanbanPersistenceManagerTests.swift` with 15 test cases:

#### Test Coverage
- ✅ Basic save and load
- ✅ Save and load boards with cards
- ✅ Multiple boards support
- ✅ Project-specific board filtering
- ✅ Current board ID tracking
- ✅ Corrupted file detection
- ✅ Corrupted file graceful fallback
- ✅ Debounced save functionality
- ✅ Board deletion
- ✅ Delete all boards
- ✅ Board count statistics
- ✅ Board exists checking
- ✅ Concurrent saves (thread safety)
- ✅ Full persistence lifecycle integration

### 4. Xcode Project Configuration
Updated `RickTerminal.xcodeproj/project.pbxproj`:
- Added `KanbanPersistenceManager.swift` to PBXBuildFile section
- Added `KanbanPersistenceManager.swift` to PBXFileReference section
- Added file to Kanban group
- Added file to PBXSourcesBuildPhase (build compilation)

---

## Architecture Decisions

### File Storage Location
- **Path**: `~/Library/Application Support/RickTerminal/Boards/`
- **Reason**: macOS standard location for app data, survives app deletions
- **Format**: JSON with pretty-printing and sorted keys for readability

### Debouncing Strategy
- **Interval**: 2 seconds
- **Implementation**: Combine's `debounce` operator
- **Reason**: Prevents excessive disk writes during rapid board changes
- **Override**: `saveNow()` method available for immediate saves

### Multiple Boards Design
- **One File Per Board**: `{boardId}.json`
- **Current Board Pointer**: Separate `current_board.json` file
- **Project Filtering**: Boards tagged with `projectRef` field
- **Reason**: Supports multiple projects/sessions, easy to backup/restore individual boards

### Corrupted File Handling
- **Detection**: Catches `DecodingError` during JSON parsing
- **Recovery**: Automatically backs up to `Corrupted/` subdirectory
- **Fallback**: Returns new default board with "Recovered" suffix in title
- **User Impact**: Minimal - app continues working, old data preserved for manual recovery

### Thread Safety
- **Board Updates**: Already thread-safe via KanbanBoard's `updateQueue`
- **Persistence**: Uses Combine publishers on main queue
- **File I/O**: Atomic writes prevent mid-write corruption
- **Observation**: `ObservableObject` ensures UI updates on main thread

---

## File Structure

```
~/Library/Application Support/RickTerminal/
├── current_board.json              # Current active board ID
└── Boards/
    ├── {uuid1}.json                # Board 1
    ├── {uuid2}.json                # Board 2
    └── Corrupted/                  # Backup location
        └── {uuid}_timestamp.json   # Corrupted file backup
```

### Example JSON Format
```json
{
  "columns" : [
    {
      "cards" : [
        {
          "assignee" : null,
          "createdAt" : "2025-02-15T14:30:00Z",
          "description" : "Task description",
          "dueDate" : null,
          "id" : "A1B2C3D4-...",
          "labels" : [],
          "priority" : 1,
          "status" : "backlog",
          "ticketRef" : "RT-027",
          "title" : "Persist Kanban Board State",
          "updatedAt" : "2025-02-15T14:30:00Z"
        }
      ],
      "color" : "#607D8B",
      "id" : "E5F6G7H8-...",
      "limit" : null,
      "order" : 0,
      "title" : "Backlog"
    }
  ],
  "createdAt" : "2025-02-15T14:00:00Z",
  "id" : "I9J0K1L2-...",
  "projectRef" : "rick-terminal",
  "title" : "Rick Terminal Tasks",
  "updatedAt" : "2025-02-15T14:30:00Z"
}
```

---

## Usage Examples

### Loading Board on App Start
```swift
let manager = KanbanManager(projectRef: "rick-terminal")
// Automatically loads last board or creates new one
```

### Switching Boards
```swift
let boards = manager.loadProjectBoards()
if let otherBoard = boards.first(where: { $0.title == "Other Board" }) {
    manager.switchBoard(otherBoard)
}
```

### Creating New Board
```swift
let newBoard = manager.createNewBoard(title: "Sprint 2024-Q1")
// Automatically saved and set as current
```

### Force Save
```swift
try? manager.saveNow()
// Bypasses 2-second debounce for immediate save
```

---

## Testing

### Running Tests
```bash
xcodebuild test -scheme RickTerminal -destination 'platform=macOS'
```

### Test Files
- `RickTerminalTests/KanbanPersistenceManagerTests.swift` - 15 test cases
- All tests include setup/teardown to avoid test pollution
- Tests verify thread safety with concurrent saves

---

## Acceptance Criteria Met

✅ **Board state saved to JSON file**
   - Implemented via `KanbanPersistenceManager.saveBoard()`
   - Uses ISO8601 dates, pretty-printed, sorted keys

✅ **State loaded on app launch**
   - `KanbanManager.init()` loads via `loadCurrentBoardId()` + `loadBoard()`
   - Falls back to new board if none exists

✅ **Saves debounced to avoid thrashing**
   - 2-second debounce via Combine's `debounce` operator
   - Triggered by `ObservableObject.objectWillChange` publisher

✅ **Multiple boards supported**
   - One JSON file per board
   - `loadBoards(forProject:)` filters by project
   - `switchBoard(_:)` changes active board

✅ **Corrupted file handled gracefully**
   - Catches `DecodingError` during load
   - Backs up to `Corrupted/` directory
   - Returns new default board via `loadBoardOrDefault()`

---

## Known Limitations

1. **No Undo/Redo**: Persistence doesn't track history
   - Mitigation: Could add versioned backups later

2. **No Cloud Sync**: Files are local only
   - Future: Could add iCloud support via FileManager.ubiquityIdentityToken

3. **No Compression**: JSON files are uncompressed
   - Current size: ~1-5KB per board (acceptable)

4. **No Migration Strategy**: JSON schema changes could break old files
   - Mitigation: Corrupted file handler provides fallback

---

## Next Steps (Optional Enhancements)

- [ ] Add board export/import feature
- [ ] Implement automatic backups (daily snapshots)
- [ ] Add board versioning for undo/redo
- [ ] Implement iCloud sync for cross-device boards
- [ ] Add board archiving (soft delete)
- [ ] Create board templates
- [ ] Add JSON schema validation

---

## References

- **ADR-002**: Kanban Board Data Model Architecture
- **RT-024**: Card Detail View (related persistence work)
- **SessionPersistenceManager**: Similar pattern for shell sessions
