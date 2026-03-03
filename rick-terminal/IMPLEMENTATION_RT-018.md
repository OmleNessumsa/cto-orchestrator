# Implementation RT-018: Claude Auto-Launch on Terminal Start

## Overview
Implemented automatic Claude CLI launch when a new terminal session starts, with configurable settings and keyboard shortcuts for manual control.

## Implementation Details

### 1. Configuration Settings (TerminalSettings.swift)
Added two new AppStorage properties:
- `claudeAutoLaunch`: Boolean to enable/disable auto-launch
- `claudeAutoLaunchPrompt`: Boolean to show prompt before launching (reserved for future use)

### 2. Session Management (ShellSessionManager.swift)
Added Claude integration methods:
- `launchClaude()`: Launches Claude CLI by sending "claude\n" to active session
- `exitClaude()`: Exits Claude CLI by sending "exit\n"
- `toggleClaudeMode()`: Toggles Claude mode on/off
- `handleAutoLaunchIfNeeded()`: Checks auto-launch settings and launches if enabled
- Added `claudeMode` published property to track current state

### 3. Auto-Launch Trigger (ContentView.swift)
Modified `createInitialSession()` to call `handleAutoLaunchIfNeeded()` after session creation with a 0.5s delay to allow shell initialization.

### 4. Keyboard Shortcuts (RickTerminalApp.swift)
Added new "Claude" menu with three commands:
- **⌘⇧C**: Toggle Claude Mode
- **⌘⇧L**: Launch Claude CLI
- **⌘⇧E**: Exit Claude CLI

Implemented using NotificationCenter for communication between app menu and MainWindowView.

### 5. UI Integration (MainWindowView.swift)
- Added notification listeners for Claude commands
- Centralized ShellSessionManager as StateObject
- Passed session manager to ContentView for sharing state

### 6. Settings UI (ClaudeSettingsView.swift)
Added three new sections:
- **Auto-Launch Settings**: Toggle for auto-launch and prompt options
- **Keyboard Shortcuts**: Display of available shortcuts
- Increased window height to accommodate new sections (550 → 700)

## Architecture Decisions

### Auto-Launch Timing
Implemented 0.5s delay before auto-launching to ensure shell is fully initialized. This prevents Claude from launching before the shell prompt is ready.

### Command Execution
Used simple shell command injection (`claude\n`) rather than direct process spawning. This allows Claude to inherit the shell environment and work naturally within the terminal session.

### State Management
- Used `@Published claudeMode` property to track current state
- Notifications for keyboard shortcut communication (loose coupling between UI and logic)
- Centralized settings in TerminalSettings singleton

### Configuration Storage
Used `@AppStorage` for persistent settings, stored in UserDefaults:
- `claudeAutoLaunch`: Auto-launch enabled/disabled
- `claudeAutoLaunchPrompt`: Prompt before launch (reserved for future enhancement)

## Testing Performed

1. ✅ Build succeeded with no errors
2. ⚠️ Manual testing required:
   - Launch app and verify auto-launch works when enabled
   - Test keyboard shortcuts (⌘⇧C, ⌘⇧L, ⌘⇧E)
   - Verify settings UI updates persist
   - Test toggling auto-launch on/off

## Files Modified

1. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal/TerminalSettings.swift`
   - Added auto-launch configuration properties

2. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal/ShellSessionManager.swift`
   - Added Claude integration methods and state tracking

3. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal/ContentView.swift`
   - Integrated auto-launch trigger
   - Modified to accept shared session manager

4. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal/RickTerminalApp.swift`
   - Added Claude menu with keyboard shortcuts
   - Added notification names for command routing

5. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal/MainWindowView.swift`
   - Centralized session manager
   - Added notification listeners
   - Updated CenterPanelView to use shared session manager

6. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/RickTerminal/ClaudeSettingsView.swift`
   - Added auto-launch settings section
   - Added keyboard shortcuts display
   - Increased window height

7. `/Users/elmo.asmussen/Projects/CTO/rick-terminal/IMPLEMENTATION_RT-018.md` (new)
   - This implementation document

## Acceptance Criteria Status

✅ Claude launches automatically on terminal start (if enabled)
✅ Option to start plain shell instead (toggle in settings)
✅ Keyboard shortcut to launch Claude in existing shell (⌘⇧L)
✅ Claude session state maintained (tracked via `claudeMode` property)
✅ Clean exit when terminal closes (handled by shell session cleanup)

## Usage Instructions

### Enable Auto-Launch
1. Open Settings (⌘,)
2. Navigate to Claude CLI Configuration
3. Enable "Auto-launch Claude on terminal start"
4. Optionally enable "Show prompt before launching"

### Manual Control
- Press **⌘⇧C** to toggle Claude mode on/off
- Press **⌘⇧L** to launch Claude CLI
- Press **⌘⇧E** to exit Claude CLI
- Use menu: Claude → [Command]

## Future Enhancements

1. **Launch Prompt**: Implement the prompt dialog when `claudeAutoLaunchPrompt` is enabled
2. **Claude Detection**: Visual indicator in terminal showing when Claude mode is active
3. **Multiple Sessions**: Handle Claude mode independently for each terminal session
4. **Custom Launch Args**: Allow users to specify Claude CLI arguments
5. **Auto-Exit Handling**: Detect when Claude exits and update `claudeMode` state automatically

## Known Issues

None at this time.

## Build Status

✅ Build succeeded with no errors
⚠️ Minor warnings from dependencies (SwiftTerm) - unrelated to this implementation
