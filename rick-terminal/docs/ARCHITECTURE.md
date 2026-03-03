# Rick Terminal Architecture Overview

This document provides a high-level overview of Rick Terminal's architecture, component relationships, and data flow patterns.

## System Overview

Rick Terminal is a native macOS application built with SwiftUI that combines terminal emulation with AI-assisted development features. The architecture emphasizes reactive patterns, clean separation of concerns, and thread-safe state management.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              Rick Terminal App                                │
├────────────────┬─────────────────────────────────┬───────────────────────────┤
│                │                                 │                           │
│  FILE BROWSER  │     CENTER PANEL                │     RIGHT PANEL           │
│                │  ┌───────────────────────────┐  │  ┌─────────────────────┐  │
│  FileTree      │  │  Terminal  │  Editor      │  │  │   Kanban Board      │  │
│  Manager       │  │  View      │  Panel       │  │  │   (KanbanManager)   │  │
│                │  └───────────────────────────┘  │  ├─────────────────────┤  │
│                │         ▲                       │  │   Agent Columns     │  │
│                │         │                       │  │   (AgentColumns-    │  │
│                │  ┌──────┴──────┐                │  │    Manager)         │  │
│                │  │ ShellSession │◄──────────────┼──┤                     │  │
│                │  │ Manager      │               │  │                     │  │
│                │  └──────┬──────┘                │  └─────────────────────┘  │
│                │         │                       │             ▲             │
│                │         ▼                       │             │             │
│                │  ┌──────────────┐               │  ┌──────────┴──────────┐  │
│                │  │ ShellSession │               │  │ ClaudeOutputParser  │  │
│                │  │ (PTY + I/O)  │───────────────┼─►│ (Event Extraction)  │  │
│                │  └──────────────┘               │  └─────────────────────┘  │
│                │                                 │                           │
└────────────────┴─────────────────────────────────┴───────────────────────────┘
```

## Core Components

### 1. Application Layer

**RickTerminalApp.swift**
- SwiftUI App entry point
- Defines window groups and menu commands
- Keyboard shortcut registration

**MainWindowView.swift**
- Three-column layout orchestration
- State managers instantiation (`ShellSessionManager`, `KanbanManager`, etc.)
- Notification-based view coordination

**LayoutState**
- Panel visibility and sizing
- Persisted via `@AppStorage`

### 2. Terminal Emulation

**ShellSession**
- PTY (pseudo-terminal) management via `posix_spawn`
- Raw I/O handling (read/write to shell process)
- Output buffering and delivery

**ShellSessionManager**
- Multi-session coordination
- Claude mode state
- Session lifecycle (create, switch, restore)

**RickTerminalViewController**
- SwiftTerm integration
- Keyboard input handling
- Copy/paste support

```
User Input ──► RickTerminalViewController ──► ShellSession ──► PTY ──► Shell Process
                                                  │
                                                  ▼
                                          Process Output
                                                  │
                                                  ▼
                                          ClaudeOutputParser (if Claude mode)
```

### 3. Claude CLI Integration

**ClaudeOutputParser**
- Stateful parser for Claude CLI output
- Regex-based tool detection
- Combine `eventPublisher` for reactive updates

**ClaudeToolEvent**
- Structured representation of tool invocations
- Types: Read, Write, Edit, Bash, Glob, Grep, WebFetch, Task, TodoWrite, etc.
- Status: Started, Completed, Failed

**TodoWriteParser**
- Extracts structured todo items from TodoWrite events
- Content normalization and hash computation
- Status mapping (pending → backlog, in_progress → inProgress, completed → done)

**KanbanEventBridge**
- Subscribes to ClaudeOutputParser events
- Creates/updates Kanban cards based on TodoWrite payloads
- Tracks manual overrides to prevent auto-updates

```
Claude CLI Output ──► ClaudeOutputParser ──► ClaudeToolEvent
                                                   │
                          ┌────────────────────────┼────────────────────────┐
                          │                        │                        │
                          ▼                        ▼                        ▼
                   AgentColumnsManager      KanbanEventBridge         (Future)
                          │                        │                  External
                          ▼                        ▼                  Integrations
                   AgentColumnView          KanbanBoardView
```

### 4. Kanban Board System

**Data Models**
- `KanbanCard`: Task representation with status, labels, priority
- `KanbanColumn`: Container for cards with optional WIP limits
- `KanbanBoard`: Root observable object with thread-safe mutations

**State Management**
- `KanbanManager`: Single source of truth for board state
- `KanbanPersistenceManager`: JSON serialization to disk
- `KanbanEventBridge`: Automatic card creation from Claude events

**Card Sources**
- `.manual`: User-created, never auto-updated
- `.claude(hash)`: Auto-created from TodoWrite, can be claimed
- `.subAgent(id, hash)`: Created from Task tool spawns
- `.ticket(ref)`: External ticket import (future)

### 5. Agent Visualization

**AgentStatus**
- Current operation type and status
- Recent operation history
- Files modified, commands run

**AgentColumnsManager**
- Subscribes to ClaudeOutputParser
- Aggregates tool events into agent-level status
- Publishes updates for UI consumption

**AgentColumnView**
- Real-time display of agent activity
- Shows current operation with icon and path
- Scrolling history of recent operations

### 6. Supporting Systems

**File Browser**
- `FileTreeManager`: Directory scanning and state
- `FileNode`: File/folder representation
- `FileBrowserView`: Tree view UI

**Editor**
- `EditorManager`: Open files and dirty state
- `EditorFile`: File content and metadata
- `CodeEditorView`: Syntax-highlighted text editing

**Keyboard Shortcuts**
- `KeyboardShortcutManager`: Shortcut registry
- `KeyboardShortcut`: Shortcut definition with ID, key, modifiers
- Customizable via Settings

**Error Handling**
- `RTError`: Domain-specific error types
- `ErrorManager`: Centralized error handling
- `ErrorAlertView`: User-facing error display

## Data Flow Patterns

### Reactive Updates (Combine)

Most state flows through Combine publishers for reactive UI updates:

```swift
// Publisher chain example
claudeParser.eventPublisher
    .filter { $0.toolType == .todoWrite }
    .receive(on: DispatchQueue.main)
    .sink { [weak self] event in
        self?.handleTodoWrite(event)
    }
    .store(in: &cancellables)
```

### Thread Safety

Model updates use serial dispatch queues:

```swift
class KanbanBoard: ObservableObject {
    private let updateQueue = DispatchQueue(label: "kanban.board.update")

    func moveCard(_ cardId: UUID, to columnId: UUID) {
        updateQueue.async { [weak self] in
            // Perform mutation
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }
}
```

### Environment Injection

View hierarchy shares state via `@EnvironmentObject`:

```swift
MainWindowView()
    .environmentObject(sessionManager)
    .environmentObject(kanbanManager)
    .environmentObject(layoutState)
```

## File Organization

```
RickTerminal/
├── RickTerminalApp.swift           # App entry, menus
├── MainWindowView.swift            # Layout orchestration
├── ContentView.swift               # Terminal wrapper
│
├── Claude/                         # Claude CLI integration
│   ├── ClaudeOutputParser.swift
│   ├── ClaudeToolEvent.swift
│   ├── KanbanEventBridge.swift
│   ├── TodoWriteParser.swift
│   ├── ClaudePathDetector.swift
│   ├── ClaudeOutputStyler.swift
│   ├── MarkdownRenderer.swift
│   └── ANSIStyler.swift
│
├── Kanban/                         # Kanban board
│   ├── KanbanBoard.swift
│   ├── KanbanCard.swift
│   ├── KanbanColumn.swift
│   ├── KanbanManager.swift
│   ├── KanbanPersistenceManager.swift
│   ├── CardSource.swift
│   └── Views/
│       ├── KanbanBoardView.swift
│       ├── KanbanColumnView.swift
│       ├── KanbanCardView.swift
│       └── CardDetailView.swift
│
├── Agent/                          # Agent visualization
│   ├── AgentColumn.swift
│   ├── AgentStatus.swift
│   ├── AgentRole.swift
│   ├── AgentColumnsManager.swift
│   └── Views/
│       ├── AgentColumnView.swift
│       └── AgentColumnsContainer.swift
│
├── Editor/                         # Code editor
│   ├── EditorManager.swift
│   ├── EditorFile.swift
│   ├── EditorPanelView.swift
│   └── CodeEditorView.swift
│
├── FileBrowser/                    # File tree
│   ├── FileTreeManager.swift
│   ├── FileNode.swift
│   └── FileBrowserView.swift
│
├── Keyboard/                       # Shortcuts
│   ├── KeyboardShortcutManager.swift
│   ├── KeyboardShortcut.swift
│   └── KeyboardShortcutsView.swift
│
├── Preferences/                    # Settings
│   ├── PreferencesView.swift
│   ├── GeneralPreferencesView.swift
│   ├── AppearancePreferencesView.swift
│   ├── TerminalPreferencesView.swift
│   └── KeyboardShortcutsPreferencesView.swift
│
├── SyntaxHighlighting/             # Code highlighting
│   ├── SyntaxHighlightingService.swift
│   ├── SyntaxHighlightingTypes.swift
│   └── FallbackSyntaxHighlighter.swift
│
├── Error/                          # Error handling
│   ├── RTError.swift
│   ├── ErrorManager.swift
│   └── ErrorAlertView.swift
│
├── Utilities/                      # Helpers
│   └── FileOperationsHelper.swift
│
├── Color+Theme.swift               # Theme colors
├── RickTheme.swift                 # Theme configuration
├── RTIcon.swift                    # Icon system
├── ShellSession.swift              # PTY management
├── ShellSessionManager.swift       # Session coordination
├── SessionPersistenceManager.swift # Session save/restore
├── TerminalView.swift              # SwiftTerm wrapper
└── TerminalSettings.swift          # Terminal preferences
```

## Architecture Decisions

Significant design decisions are documented as ADRs in `docs/adr/`:

| ADR | Topic |
|-----|-------|
| [ADR-001](adr/ADR-001-claude-tool-usage-parsing.md) | Claude output parsing architecture |
| [ADR-002](adr/ADR-002-kanban-board-data-model.md) | Kanban data model design |
| [ADR-003](adr/ADR-003-agent-column-visualization.md) | Agent column visualization |
| [ADR-004](adr/ADR-004-claude-kanban-event-bridge.md) | Event bridge between Claude and Kanban |
| [ADR-005](adr/ADR-005-app-sandbox-security-model.md) | App sandbox entitlements |
| [ADR-006](adr/ADR-006-syntax-highlighting-library.md) | Syntax highlighting approach |

## Extension Points

### Adding New Tool Types

1. Add case to `ClaudeToolType` enum
2. Update regex patterns in `ClaudeOutputParser`
3. Handle in `AgentColumnsManager` for visualization
4. (Optional) Add bridge logic if it affects Kanban

### Adding New Kanban Features

1. Extend data models (`KanbanCard`, `KanbanColumn`)
2. Update persistence schema
3. Add UI in `Kanban/Views/`
4. Consider migration strategy for existing data

### Adding New Preferences

1. Add property to `TerminalSettings` with `@AppStorage`
2. Create preference view in `Preferences/`
3. Add tab in `PreferencesView`

## Performance Considerations

- **Parsing**: Output parsing runs on background queue to avoid blocking PTY I/O
- **UI Updates**: Batched via Combine, debounced where appropriate
- **Memory**: Weak references prevent retain cycles in subscription chains
- **Persistence**: Kanban saves debounced to avoid excessive disk writes

## Security Model

Rick Terminal operates within macOS App Sandbox with minimal permissions:

- Network: Outbound only (for Claude CLI → Anthropic API)
- File System: User-selected directories + shell config files
- Process Execution: Required for PTY/shell spawning

See [SECURITY_MODEL.md](SECURITY_MODEL.md) for full details.

---

*Last updated: 2026-02-15*
