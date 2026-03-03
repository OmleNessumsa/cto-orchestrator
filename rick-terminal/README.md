# Rick Terminal

A native macOS terminal emulator with deep Claude CLI integration, featuring real-time task visualization through an integrated Kanban board and agent status columns.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

## Overview

Rick Terminal bridges the gap between traditional terminal emulation and AI-assisted development workflows. It parses Claude CLI output in real-time, extracting tool usage events and task updates to provide visual feedback through a Kanban board and agent activity columns.

### Key Features

- **Native macOS Terminal** - Full terminal emulation via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) with shell integration (zsh/bash)
- **Claude CLI Integration** - Auto-detects Claude CLI installation, tracks tool invocations, and visualizes AI agent activity
- **Live Kanban Board** - Automatic card creation from `TodoWrite` events with manual override support
- **Agent Status Columns** - Real-time visualization of file reads, writes, bash commands, and other tool usage
- **Three-Column Layout** - File browser | Terminal/Editor | Kanban & Agent panels
- **Session Persistence** - Save and restore terminal sessions across app restarts
- **Customizable Shortcuts** - Full keyboard shortcut customization
- **Dark Theme** - Rick Portal-inspired color scheme (purple/green accents on dark background)

## Screenshots

### Main Interface
```
┌─────────────────────────────────────────────────────────────────────────┐
│ Rick Terminal - Claude Mode                                              │
├──────────────┬──────────────────────────────────┬───────────────────────┤
│              │                                  │   KANBAN BOARD        │
│  FILE        │  TERMINAL / EDITOR               │   ┌────┐ ┌────┐ ┌────┐│
│  BROWSER     │                                  │   │Back│ │Prog│ │Done││
│              │  $ claude "implement feature"    │   │log │ │ress│ │    ││
│  📁 src/     │                                  │   ├────┤ ├────┤ ├────┤│
│  📁 docs/    │  ⏺ Read(file: "main.swift")     │   │Card│ │Card│ │Card││
│  📄 Package  │    [file contents...]            │   │    │ │    │ │    ││
│              │                                  │   └────┘ └────┘ └────┘│
│              │  ⏺ Write(file: "new.swift")     │───────────────────────│
│              │    Creating new file...          │   AGENT COLUMNS       │
│              │                                  │   ┌─────────────────┐ │
│              │                                  │   │ 📖 Read main.sw │ │
│              │                                  │   │ ✏️ Write new.sw  │ │
│              │                                  │   │ ⚡ Bash: npm run │ │
│              │                                  │   └─────────────────┘ │
└──────────────┴──────────────────────────────────┴───────────────────────┘
```

### Theme Colors
| Element | Color | Hex |
|---------|-------|-----|
| Background Dark | ![#0D1010](https://placehold.co/15x15/0D1010/0D1010.png) | `#0D1010` |
| Background Light | ![#1A1F1F](https://placehold.co/15x15/1A1F1F/1A1F1F.png) | `#1A1F1F` |
| Accent Purple | ![#7B78AA](https://placehold.co/15x15/7B78AA/7B78AA.png) | `#7B78AA` |
| Accent Green | ![#7FFC50](https://placehold.co/15x15/7FFC50/7FFC50.png) | `#7FFC50` |
| Text Primary | ![#FFFFFF](https://placehold.co/15x15/FFFFFF/FFFFFF.png) | `#FFFFFF` |

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+** (for building from source)
- **Claude CLI** (optional, for AI integration features)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/your-org/rick-terminal.git
cd rick-terminal

# Open in Xcode
open RickTerminal.xcodeproj

# Build and run (Cmd+R)
```

### Claude CLI Setup

Rick Terminal auto-detects Claude CLI from common installation paths:
- `/usr/local/bin/claude`
- `/opt/homebrew/bin/claude`
- `~/.local/bin/claude`

If auto-detection fails, configure manually via **Settings > Claude Integration**.

## Usage

### Basic Terminal Usage

Rick Terminal functions as a standard macOS terminal. Launch shells, run commands, and use your existing shell configuration (`.zshrc`, `.bashrc`).

### Claude Mode

Toggle Claude mode to enable AI integration features:

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+C` | Toggle Claude Mode |
| `Cmd+Shift+L` | Launch Claude CLI |
| `Cmd+Shift+X` | Exit Claude |

### Kanban Board

The Kanban board automatically populates from Claude's `TodoWrite` events:

- **Auto-created cards** - Purple badge, auto-updates with status changes
- **Manual cards** - Green badge, never auto-updated
- **Sub-agent cards** - Orange badge, tracks Task tool spawns

**Claiming cards**: Hover over an auto-created card and click "Claim" to convert it to manual control.

### Panel Management

| Shortcut | Action |
|----------|--------|
| `Cmd+B` | Toggle File Browser |
| `Cmd+K` | Toggle Kanban Board |
| `Cmd+1` | Switch to Terminal |
| `Cmd+2` | Switch to Editor |

### Window Management

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New Window |
| `Cmd+T` | New Tab |
| `Cmd+W` | Close Tab |
| `Cmd+[` | Previous Tab |
| `Cmd+]` | Next Tab |

## Architecture

### Project Structure

```
RickTerminal/
├── RickTerminalApp.swift       # App entry point, menu commands
├── MainWindowView.swift        # Three-column layout orchestration
├── ContentView.swift           # Terminal content wrapper
│
├── Claude/                     # Claude CLI integration
│   ├── ClaudeOutputParser.swift    # Parses tool usage from output
│   ├── ClaudeToolEvent.swift       # Tool event data models
│   ├── KanbanEventBridge.swift     # Connects parser to Kanban
│   ├── TodoWriteParser.swift       # Extracts todo items
│   └── ClaudePathDetector.swift    # Auto-detection logic
│
├── Kanban/                     # Kanban board system
│   ├── KanbanBoard.swift           # Observable board model
│   ├── KanbanCard.swift            # Card data model
│   ├── KanbanColumn.swift          # Column data model
│   ├── KanbanManager.swift         # State management
│   └── Views/                      # SwiftUI views
│
├── Agent/                      # Agent visualization
│   ├── AgentColumn.swift           # Column data model
│   ├── AgentColumnsManager.swift   # Aggregates tool events
│   └── Views/                      # SwiftUI views
│
├── Editor/                     # Code editor panel
├── FileBrowser/                # File tree navigation
├── Keyboard/                   # Shortcut management
├── Preferences/                # Settings views
├── SyntaxHighlighting/         # Code syntax highlighting
├── Error/                      # Error handling system
└── Utilities/                  # Helper functions
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `ShellSession` | Manages PTY, process spawning, I/O |
| `ShellSessionManager` | Multi-session coordination |
| `ClaudeOutputParser` | Real-time output parsing via Combine |
| `KanbanEventBridge` | Maps tool events to Kanban cards |
| `AgentColumnsManager` | Aggregates agent activity for display |

### Architecture Decision Records

Detailed design decisions are documented in `docs/adr/`:

- [ADR-001](docs/adr/ADR-001-claude-tool-usage-parsing.md) - Claude Tool Usage Parsing
- [ADR-002](docs/adr/ADR-002-kanban-board-data-model.md) - Kanban Board Data Model
- [ADR-003](docs/adr/ADR-003-agent-column-visualization.md) - Agent Column Visualization
- [ADR-004](docs/adr/ADR-004-claude-kanban-event-bridge.md) - Claude-Kanban Event Bridge
- [ADR-005](docs/adr/ADR-005-app-sandbox-security-model.md) - App Sandbox Security Model
- [ADR-006](docs/adr/ADR-006-syntax-highlighting-library.md) - Syntax Highlighting Library

## Development

### Building

```bash
# Build for debugging
xcodebuild -scheme RickTerminal -configuration Debug build

# Build for release
xcodebuild -scheme RickTerminal -configuration Release build

# Run tests
xcodebuild test -scheme RickTerminal -destination 'platform=macOS'
```

### Running Tests

```bash
# All tests
swift test

# Specific test file
swift test --filter KanbanBoardTests
```

### Documentation

Additional documentation in `docs/`:

- [Security Model](docs/SECURITY_MODEL.md) - App sandbox entitlements
- [Claude CLI Configuration](docs/CLAUDE_CLI_CONFIGURATION.md) - Detection and setup
- [Kanban Integration Guide](docs/KANBAN_INTEGRATION_GUIDE.md) - Event flow details
- [Icon System](docs/ICON_SYSTEM.md) - RTIcon usage guide
- [Error Handling](docs/ERROR_HANDLING.md) - Error management patterns

## Security

Rick Terminal operates within the macOS App Sandbox with minimal permissions:

- **Network**: Outbound only (Claude CLI → Anthropic API)
- **File System**: User-selected directories + shell config files
- **Process Execution**: Required for PTY/shell spawning

Full details in [docs/SECURITY_MODEL.md](docs/SECURITY_MODEL.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Code style and conventions
- Pull request process
- Testing requirements
- Architecture decisions

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - Terminal emulation library
- [Claude](https://claude.ai) - AI assistant integration
- Rick Sanchez - The smartest CTO in the multiverse
