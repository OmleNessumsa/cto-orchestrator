# Implementation: RT-025 Agent Column Visualization

## Overview
Implemented the Morty agent columns that show real-time activity. Each active sub-agent gets a column showing agent name/role, current task, recent actions, and status indicator. Columns appear/disappear as agents spawn/complete with smooth animations.

## Architecture Decision
See `docs/adr/ADR-003-agent-column-visualization.md` for full architecture details.

## Files Created

### Models (`RickTerminal/Agent/`)
| File | Description |
|------|-------------|
| `AgentRole.swift` | Enum classifying agent types (architect, backend, frontend, explorer, etc.) with display properties, icons, and theme colors |
| `AgentStatus.swift` | Lifecycle state enum (spawning, working, idle, done, error) with UI properties |
| `AgentColumn.swift` | Observable class representing a single agent column with actions log, task info, and lifecycle management |
| `AgentColumnsManager.swift` | Orchestrator that bridges `ClaudeOutputParser` events to column state, handles creation/removal/cleanup |

### Views (`RickTerminal/Agent/Views/`)
| File | Description |
|------|-------------|
| `AgentColumnView.swift` | Single column view showing header, current task, action log, and footer with stats |
| `AgentColumnsContainer.swift` | Horizontal scrolling container with header, empty state, and column animations. Also includes `AgentColumnsCompactView`, `AgentAvatarView`, and `AgentColumnsOverlay` |

### Documentation
| File | Description |
|------|-------------|
| `docs/adr/ADR-003-agent-column-visualization.md` | Architecture Decision Record documenting design choices |

## Key Features Implemented

### Acceptance Criteria
- [x] Column appears when agent detected (via Task tool event)
- [x] Column shows agent role/name (with Rick & Morty theming - "Architect Morty", etc.)
- [x] Current task displayed prominently
- [x] Action log scrolls with recent activity (capped at 50 entries)
- [x] Status indicator (spawning/working/idle/done/error) with pulsing animation
- [x] Column fades out when agent completes (configurable delay)

### Additional Features
- Role-specific theme colors (architect=purple, backend=blue, frontend=orange, etc.)
- Compact view for minimal UI footprint
- Avatar view showing multiple agents in collapsed state
- Overlay mode for placement over terminal
- Preview support for SwiftUI Previews

## Integration Points

### To use the Agent Columns system:

```swift
// 1. Create the manager
let agentManager = AgentColumnsManager()

// 2. Subscribe to parser events
agentManager.subscribe(to: claudeOutputParser)

// 3. Add to view hierarchy
AgentColumnsContainer(manager: agentManager)
// or for overlay style:
AgentColumnsOverlay(manager: agentManager, isExpanded: $isExpanded)
```

### Event Flow
```
ClaudeOutputParser
        │ eventPublisher
        ▼
AgentColumnsManager.handleEvent()
        │
        ├─[Task started]──▶ createColumn()
        ├─[Tool events]───▶ updateColumn()
        └─[Task completed]─▶ scheduleFadeOut()
```

## Project Configuration
- Added all new files to `RickTerminal.xcodeproj/project.pbxproj`
- Created `RickTerminal/Agent/` directory structure
- Created `RickTerminal/Agent/Views/` subdirectory

## Dependencies
- Uses existing `ClaudeToolEvent` and `ClaudeOutputParser` from `RickTerminal/Claude/`
- Uses existing color theme from `Color+Theme.swift` (`rtAccentPurple`, `rtAccentGreen`, etc.)
- Uses SwiftUI and Combine frameworks

## Testing
Debug-only preview support is included:
- `AgentColumnsManager.preview` - Creates manager with mock data
- `AgentColumnView_Previews` - Preview provider for single column
- `AgentColumnsContainer_Previews` - Preview provider for container

## Next Steps (for integration)
1. Wire `AgentColumnsManager` to the main app's `ClaudeOutputParser`
2. Add `AgentColumnsContainer` or `AgentColumnsOverlay` to the main view hierarchy
3. Configure placement (below terminal, overlay, or separate panel)
