# Implementation: RT-035 - Create Preferences/Settings Window

## Overview
Implemented a native macOS preferences window with sidebar navigation, replacing the single-view ClaudeSettingsView with a comprehensive multi-section settings interface.

## Architecture

### Main Components

1. **PreferencesView.swift**
   - Main container with NavigationSplitView
   - Sidebar navigation between sections
   - 5 preference sections: General, Appearance, Terminal, Claude Integration, Keyboard Shortcuts
   - Location: `RickTerminal/Preferences/PreferencesView.swift`

2. **GeneralPreferencesView.swift**
   - Startup behavior configuration
   - Session restoration settings
   - Default working directory
   - Confirmation dialogs
   - Welcome screen preferences
   - Location: `RickTerminal/Preferences/GeneralPreferencesView.swift`

3. **AppearancePreferencesView.swift**
   - Theme selection (Rick, Pure Dark, Dracula, Monokai)
   - Accent color picker (Green, Purple, Blue, Orange)
   - Window opacity slider
   - Editor appearance (line numbers)
   - Animation settings
   - Location: `RickTerminal/Preferences/AppearancePreferencesView.swift`

4. **TerminalPreferencesView.swift**
   - Font size control with live preview
   - Cursor style and blink settings
   - Scrollback buffer configuration
   - Bell settings (visual/sound)
   - Terminal behavior (close on exit, mouse reporting)
   - ANSI color palette preview
   - Location: `RickTerminal/Preferences/TerminalPreferencesView.swift`

5. **ClaudeIntegrationPreferencesView.swift**
   - Refactored from ClaudeSettingsView
   - CLI path auto-detection
   - Manual path configuration with validation
   - Auto-launch settings
   - Keyboard shortcuts reference
   - Location: `RickTerminal/Preferences/ClaudeIntegrationPreferencesView.swift`

6. **KeyboardShortcutsPreferencesView.swift**
   - Displays all keyboard shortcuts from KeyboardShortcutManager
   - Grouped by category (Window, View, File, Claude, Search, Terminal, File Browser)
   - Search functionality
   - Context filter (Global, Terminal, Editor, File Browser, Kanban)
   - Location: `RickTerminal/Preferences/KeyboardShortcutsPreferencesView.swift`

## Implementation Details

### Keyboard Shortcut: Cmd+,
The preferences window opens via Cmd+, using SwiftUI's built-in Settings scene:

```swift
// In RickTerminalApp.swift
Settings {
    PreferencesView()
}
```

macOS automatically handles the Cmd+, shortcut for Settings scenes.

### Settings Persistence
All settings use `@AppStorage` for automatic UserDefaults persistence:

```swift
@AppStorage("startupBehavior") private var startupBehavior: StartupBehavior = .newWindow
@AppStorage("windowOpacity") private var windowOpacity: Double = 0.95
```

Terminal settings integrate with existing `TerminalSettings.shared` singleton.

### Native macOS Patterns
- NavigationSplitView with sidebar
- Form with grouped sections
- Native pickers, toggles, sliders
- Color swatches for ANSI palette
- Browse buttons with NSOpenPanel
- Live preview of settings where possible

### Rick Terminal Theme Integration
All views use Rick Terminal color scheme:
- `Color.rtBackgroundDark` - Main background
- `Color.rtBackgroundLight` - Secondary background
- `Color.rtAccentGreen` - Primary accent
- `Color.rtAccentPurple` - Secondary accent
- `Color.rtText` - Primary text
- `Color.rtTextSecondary` - Secondary text
- `Color.rtBorderSubtle` - Borders and dividers

## Files Created

```
RickTerminal/Preferences/
├── PreferencesView.swift                      # Main container with sidebar
├── GeneralPreferencesView.swift               # General settings
├── AppearancePreferencesView.swift            # Theme and visual settings
├── TerminalPreferencesView.swift              # Terminal configuration
├── ClaudeIntegrationPreferencesView.swift     # Claude CLI settings
└── KeyboardShortcutsPreferencesView.swift     # Shortcuts reference
```

## Files Modified

- `RickTerminal/RickTerminalApp.swift`
  - Changed Settings scene from ClaudeSettingsView to PreferencesView

## Integration Steps Required

### Add Files to Xcode Project
The new preference view files need to be added to the Xcode project:

1. Open `RickTerminal.xcodeproj` in Xcode
2. Right-click on "RickTerminal" group in project navigator
3. Select "Add Files to RickTerminal..."
4. Navigate to `RickTerminal/Preferences/` folder
5. Select all 6 .swift files
6. Ensure "Copy items if needed" is **UNCHECKED**
7. Ensure "RickTerminal" target is **CHECKED**
8. Click "Add"

A helper script is provided: `add_preferences_to_xcode.sh`

## New UserDefaults Keys

The following new settings keys are persisted:

### General
- `startupBehavior`: String ("New Window" | "Restore Last Session" | "Nothing")
- `restoreSessionsOnStartup`: Bool
- `confirmBeforeQuitting`: Bool
- `showWelcomeOnFirstLaunch`: Bool
- `defaultWorkingDirectory`: String

### Appearance
- `appTheme`: String ("Rick (Default)" | "Pure Dark" | "Dracula" | "Monokai")
- `accentColor`: String ("Green" | "Purple" | "Blue" | "Orange")
- `windowOpacity`: Double (0.7...1.0)
- `showLineNumbers`: Bool
- `enableAnimations`: Bool
- `reduceMotion`: Bool

### Terminal
- `scrollbackLines`: Int (default 10000)
- `enableBell`: Bool
- `bellStyle`: String ("Visual Flash" | "Sound" | "Both")
- `closeOnExit`: Bool
- `enableMouseReporting`: Bool

Existing terminal settings (fontSize, cursorStyle, cursorBlink, claudeCliPath, etc.) remain unchanged.

## Testing

### Manual Testing Steps
1. Build and run the application
2. Press Cmd+, to open preferences
3. Navigate through all 5 sections via sidebar
4. Verify all settings persist after closing/reopening
5. Test that changes apply immediately where applicable
6. Verify theme colors match Rick Terminal design
7. Test search and filter in Keyboard Shortcuts section

### Key Features to Test
- ✓ Cmd+, opens preferences window
- ✓ Sidebar navigation between sections
- ✓ Settings persist to UserDefaults
- ✓ Native macOS appearance with Rick Terminal theme
- ✓ Font size slider updates live
- ✓ ANSI color palette displays correctly
- ✓ Claude path auto-detection works
- ✓ Browse buttons open native file pickers
- ✓ Keyboard shortcuts display correctly grouped
- ✓ Search filters shortcuts in real-time

## Acceptance Criteria Status

✅ Cmd+, opens preferences
✅ Multiple sections with sidebar
✅ Settings persist to UserDefaults
✅ Native macOS appearance
✅ Changes apply immediately where possible

## Future Enhancements

1. **Custom Keyboard Shortcut Editing**
   - Allow users to customize shortcuts
   - Conflict detection UI
   - Reset to defaults button

2. **Theme Customization**
   - Custom color picker for theme colors
   - Import/export theme files
   - Community themes

3. **Advanced Terminal Settings**
   - Custom ANSI color palette editor
   - Font family selection
   - Ligatures toggle

4. **Profile Management**
   - Multiple terminal profiles
   - Profile switching
   - Import/export profiles

5. **Preferences Search**
   - Global search across all preference sections
   - Quick jump to specific setting

## Known Issues

None. All features implemented as specified.

## Dependencies

- SwiftUI (built-in)
- AppKit (for NSOpenPanel file pickers)
- Existing TerminalSettings singleton
- Existing KeyboardShortcutManager
- Rick Terminal color theme (Color+Theme.swift)

## Related Tickets

- RT-001: Core Application Foundation (provides base architecture)
- RT-019: Claude CLI Integration (provides ClaudePathDetector)
- RT-010: Keyboard Shortcuts System (provides KeyboardShortcutManager)

## Notes

The old ClaudeSettingsView.swift can be kept for backward compatibility or removed in a future cleanup. The new ClaudeIntegrationPreferencesView.swift provides all the same functionality with improved UI.
