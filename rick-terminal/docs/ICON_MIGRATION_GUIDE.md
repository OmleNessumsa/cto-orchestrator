# Icon System Migration Guide

## Overview

This guide helps you migrate from string-based SF Symbol names to the centralized `RTIcon` system.

## Why Migrate?

**Problems with string-based icons:**
```swift
Image(systemName: "sidebar.left.fill")  // ❌ Typo-prone
Image(systemName: "sideBar.left")       // ❌ Wrong name - silent failure
Image(systemName: "terminal")            // ❌ No autocomplete help
```

**Benefits of RTIcon:**
```swift
RTIcon.sidebarLeftFilled.image  // ✅ Type-safe
RTIcon.terminal.image           // ✅ Autocomplete
RTIcon.                         // ✅ Shows all available icons
```

## Quick Reference

| Old String-based | New RTIcon | Category |
|-----------------|------------|----------|
| `"terminal"` | `RTIcon.terminal` | App Mode |
| `"doc.text"` | `RTIcon.document` | File |
| `"sidebar.left"` | `RTIcon.sidebarLeft` | Navigation |
| `"sidebar.left.fill"` | `RTIcon.sidebarLeftFilled` | Navigation |
| `"sidebar.right"` | `RTIcon.sidebarRight` | Navigation |
| `"sidebar.right.fill"` | `RTIcon.sidebarRightFilled` | Navigation |
| `"plus.circle"` | `RTIcon.add` | Action |
| `"xmark"` | `RTIcon.close` | Action |
| `"xmark.circle.fill"` | `RTIcon.closeCircleFilled` | Action |
| `"chevron.right"` | `RTIcon.chevronRight` | Navigation |
| `"chevron.down"` | `RTIcon.chevronDown` | Navigation |
| `"folder.fill"` | `RTIcon.folderFilled` | Folder |
| `"folder.fill.badge.minus"` | `RTIcon.folderMinusFilled` | Folder |
| `"folder.badge.plus"` | `RTIcon.folderCreate` | Folder |
| `"folder.badge.questionmark"` | `RTIcon.folderQuestion` | Folder |
| `"magnifyingglass"` | `RTIcon.search` | Search |
| `"magnifyingglass.circle"` | `RTIcon.searchCircle` | Search |
| `"eye.fill"` | `RTIcon.visible` | Status |
| `"eye.slash.fill"` | `RTIcon.hidden` | Status |
| `"eye"` | `RTIcon.review` | Workflow |
| `"arrow.clockwise"` | `RTIcon.refresh` | Action |
| `"arrow.triangle.2.circlepath"` | `RTIcon.sync` | Action |
| `"checkmark.circle"` | `RTIcon.checkCircle` | Status |
| `"checkmark.circle.fill"` | `RTIcon.checkCircleFilled` | Status |
| `"exclamationmark.triangle"` | `RTIcon.warning` | Status |
| `"exclamationmark.triangle.fill"` | `RTIcon.warningFilled` | Status |
| `"xmark.octagon"` | `RTIcon.blocked` | Workflow |
| `"tray"` | `RTIcon.backlog` | Workflow |
| `"arrow.right.circle"` | `RTIcon.inProgress` | Workflow |
| `"sparkles"` | `RTIcon.ai` | Source |
| `"hand.tap"` | `RTIcon.manual` | Source |
| `"ticket"` | `RTIcon.ticket` | Source |
| `"person.crop.circle.badge.clock"` | `RTIcon.subAgent` | Source |
| `"building.columns"` | `RTIcon.architect` | Agent Role |
| `"server.rack"` | `RTIcon.backend` | Agent Role |
| `"macwindow"` | `RTIcon.frontend` | Agent Role |
| `"map"` | `RTIcon.planner` | Agent Role |
| `"person.crop.circle"` | `RTIcon.person` | Agent Role |
| `"person.3.fill"` | `RTIcon.team` | Agent Role |
| `"gearshape"` | `RTIcon.settings` | App Mode |
| `"gearshape.2.fill"` | `RTIcon.working` | Agent Status |
| `"book"` | `RTIcon.book` | Agent Role |
| `"pause.circle"` | `RTIcon.idle` | Agent Status |
| `"clock"` | `RTIcon.clock` | Time |
| `"calendar"` | `RTIcon.calendar` | Time |
| `"person.circle.fill"` | `RTIcon.assignee` | Card |
| `"number.circle"` | `RTIcon.number` | Card |
| `"pencil"` | `RTIcon.edit` | File |
| `"doc.badge.plus"` | `RTIcon.fileCreate` | File |
| `"globe"` | `RTIcon.web` | Network |
| `"checklist"` | `RTIcon.checklist` | Tool |
| `"questionmark.circle"` | `RTIcon.question` | Status |
| `"questionmark.square"` | `RTIcon.questionSquare` | Status |
| `"wand.and.stars"` | `RTIcon.magic` | Tool |
| `"rectangle.expand.vertical"` | `RTIcon.expand` | Action |
| `"arrow.down"` | `RTIcon.priorityLow` | Priority |
| `"minus"` | `RTIcon.priorityMedium` | Priority |
| `"arrow.up"` | `RTIcon.priorityHigh` | Priority |

## Migration Patterns

### Pattern 1: Simple Image Replacement

**Before:**
```swift
Image(systemName: "terminal")
    .foregroundColor(.rtAccentGreen)
```

**After:**
```swift
RTIcon.terminal.image
    .foregroundColor(.rtAccentGreen)
```

### Pattern 2: Button Icons

**Before:**
```swift
Button(action: { toggleSidebar() }) {
    Image(systemName: "sidebar.left.fill")
        .foregroundColor(.rtAccentGreen)
        .frame(width: 24, height: 24)
}
```

**After:**
```swift
Button(action: { toggleSidebar() }) {
    RTIcon.sidebarLeftFilled.image
        .foregroundColor(.rtAccentGreen)
        .frame(width: 24, height: 24)
}
```

### Pattern 3: Conditional Icons

**Before:**
```swift
Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
    .foregroundColor(.rtTextPrimary)
```

**After:**
```swift
(isExpanded ? RTIcon.chevronDown : RTIcon.chevronRight).image
    .foregroundColor(.rtTextPrimary)
```

### Pattern 4: Label with Icon

**Before:**
```swift
Label {
    Text("Terminal")
} icon: {
    Image(systemName: "terminal")
}
```

**After:**
```swift
Label {
    Text("Terminal")
} icon: {
    RTIcon.terminal.image
}
```

### Pattern 5: Font Size Customization

**Before:**
```swift
Image(systemName: "terminal")
    .font(.system(size: 20))
```

**After:**
```swift
RTIcon.terminal.image(size: 20)
// Or with color:
RTIcon.terminal.image(size: 20, color: .rtAccentGreen)
```

## Step-by-Step Migration

### Step 1: Find All Image(systemName:) Calls

Use Xcode's find feature to search for:
```
Image(systemName:
```

### Step 2: Identify the Icon

Look at the string value and find the matching `RTIcon` case from the quick reference table above.

### Step 3: Replace with RTIcon

Replace the `Image(systemName: "...")` with `RTIcon.iconName.image`

### Step 4: Test

Build and run to ensure the icons display correctly.

## Automated Migration (Optional)

You can use regex find-and-replace for common patterns:

**Find:**
```regex
Image\(systemName: "([^"]+)"\)
```

**Manual Review:**
Each match should be evaluated individually. Reference the Quick Reference table above to find the correct `RTIcon` case.

## Common Pitfalls

### Pitfall 1: Missing Icon

If an icon you need isn't in RTIcon yet:

1. Open `RTIcon.swift`
2. Add it to the appropriate category
3. Add to the backward compatibility mapping
4. Document it

Example:
```swift
// In RTIcon enum
case newIcon = "star.fill"

// In backward compatibility
case "star.fill": return .newIcon
```

### Pitfall 2: Wrong Icon Category

Make sure you're using the right semantic icon:

❌ **Wrong:**
```swift
RTIcon.close.image  // Using X for done status
```

✅ **Correct:**
```swift
RTIcon.checkCircleFilled.image  // Using checkmark for done
```

### Pitfall 3: String Interpolation

Don't try to build icon names dynamically:

❌ **Wrong:**
```swift
let iconName = "sidebar.\(side).fill"
Image(systemName: iconName)
```

✅ **Correct:**
```swift
let icon = isLeft ? RTIcon.sidebarLeftFilled : RTIcon.sidebarRightFilled
icon.image
```

## Testing After Migration

1. **Visual Check**: Run the app and verify icons display correctly
2. **Compile Check**: Ensure no build errors
3. **Autocomplete Test**: Type `RTIcon.` and verify autocomplete works
4. **Refactor Test**: Try renaming an icon to ensure all usages update

## Migration Checklist

- [ ] Replace all `Image(systemName:)` in views
- [ ] Update button icons
- [ ] Update label icons
- [ ] Update conditional icon logic
- [ ] Test all views visually
- [ ] Remove unused icon string constants
- [ ] Update documentation
- [ ] Run tests

## Example Files Already Migrated

None yet - this is the initial icon system implementation.

## Files That Need Migration

Search for `Image(systemName:` in these directories:
- `RickTerminal/*.swift`
- `RickTerminal/Agent/Views/*.swift`
- `RickTerminal/Kanban/Views/*.swift`
- `RickTerminal/FileBrowser/*.swift`
- `RickTerminal/Editor/*.swift`
- `RickTerminal/Keyboard/*.swift`

## Questions?

If you run into issues during migration:
1. Check the Quick Reference table
2. Look at `RTIcon+Examples.swift` for patterns
3. Verify the icon exists in `RTIcon.swift`
4. Add it if it's missing

## Related Documentation

- [Icon System Overview](./ICON_SYSTEM.md)
- [RTIcon Examples](../RickTerminal/RTIcon+Examples.swift)
