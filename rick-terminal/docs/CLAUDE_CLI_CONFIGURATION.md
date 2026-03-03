# Claude CLI Configuration

## Overview

Rick Terminal includes automatic detection and configuration of the Claude CLI executable. This allows the terminal to integrate Claude AI capabilities seamlessly.

## Features

### 1. Auto-Detection

The system automatically searches for Claude CLI in common installation locations:
- `/usr/local/bin/claude`
- `/opt/homebrew/bin/claude` (Homebrew on Apple Silicon)
- `/opt/local/bin/claude` (MacPorts)
- `~/.local/bin/claude` (User local installation)
- `/usr/bin/claude` (System installation)

Additionally, the system uses the `which` command as a fallback to find Claude in the system PATH.

### 2. Manual Configuration

If auto-detection fails or you have Claude CLI installed in a non-standard location, you can manually configure the path through the Settings window.

**To open Settings:**
- Press `Cmd+,` (Command + Comma)
- Or select `RickTerminal > Settings...` from the menu bar

**In the Settings window:**
1. Click "Auto-Detect Claude CLI" to attempt automatic detection
2. Or manually enter the path in the text field
3. Click "Browse..." to use a file picker
4. Click "Validate & Save" to verify and store the path

### 3. Path Validation

The system validates that:
- The file exists at the specified path
- The file is executable
- The file responds to `--version` command (confirms it's actually Claude CLI)

### 4. Persistent Storage

Once configured, the Claude CLI path is stored in `UserDefaults` and persists across application launches.

## Implementation Details

### Files

- **`ClaudePathDetector.swift`**: Core detection and validation logic
- **`TerminalSettings.swift`**: Settings storage and retrieval using `@AppStorage`
- **`ClaudeSettingsView.swift`**: SwiftUI settings interface

### Architecture

```
┌─────────────────────────┐
│  ClaudeSettingsView     │  (UI Layer)
│  - Auto-detect button   │
│  - Manual input field   │
│  - Validation display   │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   TerminalSettings      │  (State Management)
│   - claudeCliPath       │
│   - getClaudeCliPath()  │
│   - setClaudeCliPath()  │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  ClaudePathDetector     │  (Business Logic)
│  - autoDetect()         │
│  - isValidClaudePath()  │
│  - verifyExecutable()   │
└─────────────────────────┘
```

### Usage in Code

```swift
// Get the configured Claude CLI path
if let claudePath = TerminalSettings.shared.getClaudeCliPath() {
    print("Claude CLI: \(claudePath)")
} else {
    print("Claude CLI not configured")
}

// Manually set a path
let success = TerminalSettings.shared.setClaudeCliPath("/custom/path/to/claude")
if success {
    print("Path validated and saved")
} else {
    print("Invalid path")
}

// Reset detection (force re-detection)
TerminalSettings.shared.resetClaudeCliDetection()
```

## User Experience

### First Launch
On first launch, the app will attempt auto-detection when `getClaudeCliPath()` is first called. This happens lazily to avoid startup delays.

### Error Handling
If Claude CLI is not found:
1. The settings UI shows "Not configured" status
2. User can click "Auto-Detect" to retry
3. User can manually configure the path
4. Helpful validation messages guide the user

### Success Indicators
- Green checkmark icon when configured
- Path displayed in monospace font for clarity
- "Path is valid and saved" confirmation message

## Testing

Run the test script to verify detection on your system:

```bash
swift test_claude_detection.swift
```

This will show which paths exist and whether Claude CLI was found.

## Troubleshooting

### Claude CLI not detected
1. Verify Claude CLI is installed: `which claude`
2. Check if it's executable: `ls -la $(which claude)`
3. Try manual configuration in Settings
4. Ensure the path points to the actual `claude` executable, not a wrapper script

### Validation fails
1. Run `claude --version` in Terminal to ensure it works
2. Check file permissions: `chmod +x /path/to/claude`
3. If using a custom installation, provide the full absolute path

### Path not persisting
1. Check `UserDefaults` access (ensure app has proper permissions)
2. Try resetting detection: Settings > "Reset Detection"
3. Reconfigure the path

## Future Enhancements

Potential improvements:
- [ ] Automatically detect when Claude CLI is installed/updated
- [ ] Support for multiple Claude CLI versions
- [ ] Integration with Homebrew to auto-install if missing
- [ ] Health check to verify Claude CLI is working correctly
- [ ] Version compatibility warnings
