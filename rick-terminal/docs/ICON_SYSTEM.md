# Rick Terminal Icon System

## Overview

The Rick Terminal icon system provides a centralized, type-safe way to use SF Symbols throughout the application. **NO EMOJIS** - this is a professional application using Apple's SF Symbols icon set.

## Files

- **`RickTerminal/RTIcon.swift`** - Main icon enum with all available icons
- **`RickTerminal/RTIcon+Examples.swift`** - Usage examples (DEBUG only)

## Quick Start

### Basic Usage

```swift
// Simple icon
RTIcon.terminal.image
    .foregroundColor(.rtAccentGreen)

// Icon with size
RTIcon.folder.image(size: 24)

// Icon with size and color
RTIcon.add.image(size: 16, color: .rtAccentPurple)
```

### In Buttons

```swift
Button(action: { toggleSidebar() }) {
    RTIcon.sidebarLeft.image
        .foregroundColor(.rtAccentGreen)
        .frame(width: 24, height: 24)
}
.buttonStyle(.plain)
.help("Toggle Sidebar")
```

### Conditional Icons

```swift
Button(action: { isExpanded.toggle() }) {
    (isExpanded ? RTIcon.chevronDown : RTIcon.chevronRight).image
        .foregroundColor(.rtTextPrimary)
}
```

## Icon Categories

### Navigation & UI Chrome
- `sidebarLeft`, `sidebarRight` - Sidebar toggles
- `chevronRight`, `chevronDown` - Expansion indicators
- `close`, `closeCircle` - Close buttons
- `add`, `addFilled` - Create/Add actions

### Application Modes
- `terminal` - Terminal mode
- `document` - Editor/Document mode
- `settings` - Configuration/Settings

### File Operations
- `file`, `textFile`, `richText` - File types
- `code`, `swift` - Programming files
- `fileCreate` - Create new file
- `edit` - Edit file

### Folders
- `folder`, `folderFilled` - Standard folders
- `folderCreate` - Create folder
- `folderQuestion` - Unknown/Empty folder

### Git/Version Control
- `gitBranch` - Git branch
- `build` - Build/Hammer

### Search
- `search`, `searchCircle` - Search functionality

### Status Indicators
- `check`, `checkCircle` - Success/Complete
- `warning` - Warnings/Alerts
- `error` - Errors
- `info`, `question` - Information/Help

### Priority Indicators
- `priorityLow` - Low priority (arrow down)
- `priorityMedium` - Medium priority (minus)
- `priorityHigh` - High priority (arrow up)
- `priorityCritical` - Critical priority (warning triangle)

### Workflow Status
- `backlog` - Backlog/Inbox
- `inProgress` - In progress
- `review` - Under review
- `done` - Completed
- `blocked` - Blocked

### Card Sources
- `manual` - User-created
- `ai` - Claude-generated
- `ticket` - Ticket reference
- `subAgent` - Sub-agent task

### Agent Roles
- `architect` - Architect role
- `backend` - Backend role
- `frontend` - Frontend role
- `explorer` - Explorer role
- `planner` - Planner role
- `person` - General purpose
- `team` - Multiple agents
- `book` - Guide/Documentation

### Agent Status
- `working` - Active work
- `idle` - Paused/Idle
- `play`, `stop` - Control actions

### Time & Schedule
- `clock` - Time indicator
- `calendar` - Calendar/Due date

### Tool Types
- `bash` - Terminal command
- `web` - Web/Network
- `checklist` - Todo list
- `magic` - Skills/Magic wand
- `notebook` - Notebook

### Media Types
- `photo` - Images
- `film` - Video
- `music` - Audio
- `archive` - Compressed files

### Actions
- `refresh` - Reload/Refresh
- `sync` - Synchronize
- `expand` - Expand view
- `number` - Counter/Number
- `assignee` - Person assigned

## Migration from String-based Icons

### Before (Error-prone)
```swift
Image(systemName: "sidebar.left.fill")
    .foregroundColor(.rtAccentGreen)
```

### After (Type-safe)
```swift
RTIcon.sidebarLeftFilled.image
    .foregroundColor(.rtAccentGreen)
```

### Benefits
- ✅ Autocomplete helps find the right icon
- ✅ Compiler catches typos
- ✅ Easy to refactor (find all usages)
- ✅ Centralized management
- ✅ Consistent naming
- ✅ No emoji usage

## Common Patterns

### Pattern 1: Icon + Text Label
```swift
Label {
    Text("Terminal")
} icon: {
    RTIcon.terminal.image
}
```

### Pattern 2: Icon Button with Tooltip
```swift
Button(action: { openSettings() }) {
    RTIcon.settings.image
        .foregroundColor(.rtAccentGreen)
        .frame(width: 24, height: 24)
}
.buttonStyle(.plain)
.help("Open Settings")
```

### Pattern 3: Status Badge
```swift
ZStack(alignment: .topTrailing) {
    RTIcon.document.image
        .font(.system(size: 24))

    // Unsaved indicator
    Circle()
        .fill(Color.rtAccentGreen)
        .frame(width: 8, height: 8)
        .offset(x: 4, y: -4)
}
```

### Pattern 4: Icon with Background
```swift
ZStack {
    Circle()
        .fill(Color.rtAccentPurple.opacity(0.2))
        .frame(width: 32, height: 32)

    RTIcon.ai.image
        .foregroundColor(.rtAccentPurple)
}
```

## Adding New Icons

When you need a new icon:

1. Find the SF Symbol name (use SF Symbols app)
2. Add it to the `RTIcon` enum in the appropriate category
3. Add a backward compatibility mapping if needed
4. Document it in this file

Example:
```swift
// In RTIcon.swift
enum RTIcon: String {
    // ... existing icons ...

    /// New feature icon
    case newFeature = "star.fill"

    // ... rest of enum ...
}
```

## Color Guidelines

Use theme colors for consistency:

- **Primary actions**: `.rtAccentGreen` (green)
- **Secondary actions**: `.rtAccentPurple` (purple)
- **Text/Default**: `.rtTextPrimary`, `.rtTextSecondary`
- **Muted/Disabled**: `.rtMuted`
- **Success**: `Color(hex: "4CAF50")` (green)
- **Warning**: `Color(hex: "FF9800")` (orange)
- **Error**: `Color(hex: "F44336")` (red)
- **Info**: `.rtAccentPurple` or `.rtAccentBlue`

## Icon Size Guidelines

- **Toolbar icons**: 24x24 or 20x20
- **List/Row icons**: 16x16 or 14x14
- **Buttons**: 20x20 or 18x18
- **Large feature icons**: 32x32 or 48x48
- **Status indicators**: 12x12 or 14x14

Use `.font(.system(size: X))` for precise sizing.

## Accessibility

All SF Symbols are automatically accessible. For better accessibility:

```swift
RTIcon.settings.image
    .foregroundColor(.rtAccentGreen)
    .accessibilityLabel("Settings")
    .accessibilityHint("Open application settings")
```

## Performance

The icon system has minimal performance impact:
- Enum-based (zero runtime cost)
- SF Symbols are system-provided (cached by OS)
- Type-safe (compile-time checking)

## App Icon

The Rick Terminal app icon is a distinctive terminal prompt symbol (`>_`) rendered in the signature Rick Terminal green (`#7FFC50`) on a dark background (`#0D1010`) with a subtle purple border accent (`#7B78AA`).

### App Icon Design
- **Symbol**: Terminal prompt `>_` with green glow effect
- **Background**: Dark gradient with subtle highlights
- **Border**: Purple accent border for brand recognition
- **Style**: macOS Big Sur+ rounded rectangle (22% corner radius)

### App Icon Sizes
All required macOS sizes are in `RickTerminal/Assets.xcassets/AppIcon.appiconset/`:
- 16x16 (1x, 2x)
- 32x32 (1x, 2x)
- 128x128 (1x, 2x)
- 256x256 (1x, 2x)
- 512x512 (1x, 2x) - includes 1024x1024 master

### Regenerating App Icons
To regenerate app icons (e.g., after design changes):
```bash
swift Scripts/GenerateAppIcon.swift
```

The generator creates all required sizes programmatically using the theme colors.

## Related Documentation

- [Theme System](./THEME_SYSTEM.md)
- [Color Guidelines](./COLOR_GUIDELINES.md)
- [SF Symbols Documentation](https://developer.apple.com/sf-symbols/)

## Questions?

If you need help or have questions about the icon system, check:
1. `RTIcon+Examples.swift` for usage examples
2. This documentation
3. Existing usage in the codebase (search for `RTIcon.`)
