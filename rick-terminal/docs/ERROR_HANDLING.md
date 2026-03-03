# Error Handling System

Rick Terminal implements a comprehensive error handling system that provides clear user feedback, detailed logging, and recovery suggestions for common failures.

## Overview

The error handling system consists of three main components:

1. **RTError** - Categorized error types with user-friendly messages
2. **ErrorManager** - Centralized error handling and logging
3. **Error UI Components** - User-facing error presentation

## Architecture

### RTError Enum

All errors in Rick Terminal are represented using the `RTError` enum, which provides:

- User-friendly error messages
- Technical details for logging
- Recovery action suggestions
- Severity levels
- Automatic categorization

Example:
```swift
enum RTError: Error {
    case claudeNotFound
    case filePermissionDenied(String)
    case gitCommandFailed(String, Error)
    // ... more cases
}
```

### Error Categories

Errors are organized into categories:

1. **Claude CLI Errors** - Claude installation, configuration, and launch issues
2. **File Operation Errors** - File I/O, permissions, and path issues
3. **Git Operation Errors** - Git command failures and repository issues
4. **Shell Session Errors** - Terminal session creation and management
5. **Network Errors** - Connectivity and API issues
6. **General Errors** - Configuration and unknown errors

### Error Severity

Each error has a severity level:

- `info` - Informational messages
- `warning` - Non-critical issues that may require attention
- `error` - Standard errors that prevent an operation
- `critical` - Severe errors that may affect application stability

## Usage

### Handling Errors

Use `ErrorManager.shared.handle()` to process errors:

```swift
// Simple error handling
ErrorManager.shared.handle(.claudeNotFound)

// With context
ErrorManager.shared.handle(
    .fileReadFailed(path, error),
    sessionId: session.id,
    additionalInfo: ["operation": "load config"]
)

// Without user notification
ErrorManager.shared.handle(
    .operationCancelled,
    presentToUser: false
)
```

### Creating Error-Safe Functions

For file operations and other error-prone code:

```swift
func loadConfiguration() {
    let result = FileOperationsHelper.shared.readFile(at: configPath)

    switch result {
    case .success(let content):
        // Process content
    case .failure(let error):
        // Error already logged and presented to user
        return
    }
}
```

### Error Recovery

Provide recovery actions in error definitions:

```swift
case .claudeNotFound:
    return [
        "Install Claude CLI: npm install -g @anthropic-ai/claude-cli",
        "Or manually configure the path in Settings"
    ]
```

## UI Components

### ErrorAlertView

Native macOS alerts with recovery suggestions:

```swift
MainWindowView()
    .errorAlert() // Enable error alerts
```

Features:
- Automatic presentation when errors occur
- Recovery action suggestions
- "View Error Log" button for logged errors
- Severity-appropriate styling

### ErrorBannerView

Inline error banners for contextual errors:

```swift
ErrorBannerView(
    error: .claudeNotConfigured,
    onDismiss: { /* handle dismiss */ }
)
```

Use cases:
- Form validation errors
- Real-time feedback
- Non-blocking notifications

### ErrorStateView

Empty state views for failed operations:

```swift
ErrorStateView(
    error: .fileNotFound(path),
    retry: { loadFile() }
)
```

Features:
- Visual error representation
- Recovery suggestions
- Optional retry button
- Used for empty/failed list states

## Error Logging

### Log Location

Errors are logged to:
```
~/Library/Application Support/RickTerminal/errors.log
```

### Log Format

```
[2025-02-15 10:30:45] [error] ShellSession.swift:85 start()
Error: Failed to spawn shell process
Session: 12345678-1234-1234-1234-123456789abc
Additional Info:
  shell: /bin/zsh
  workingDirectory: /Users/user/project
  posix_errno: 13
```

### Log Management

```swift
// Open log file
ErrorManager.shared.openErrorLog()

// Get recent errors
let recentLog = ErrorManager.shared.getRecentErrorLog(limit: 50)

// Clear log
ErrorManager.shared.clearErrorLog()
```

## Best Practices

### 1. Always Handle Errors

Never silently fail. Use the error handling system for all error-prone operations:

```swift
// ❌ Bad
do {
    try operation()
} catch {
    print("Error: \(error)")
}

// ✅ Good
do {
    try operation()
} catch {
    ErrorManager.shared.handle(error)
}
```

### 2. Provide Context

Include relevant context in error handlers:

```swift
ErrorManager.shared.handle(
    .sessionCreationFailed(error),
    sessionId: sessionId,
    additionalInfo: [
        "shell": shellType,
        "workingDirectory": workDir
    ]
)
```

### 3. Use Appropriate Severity

Choose the right severity level:

```swift
// Warning for recoverable issues
case .claudeNotConfigured:
    return .warning

// Error for operation failures
case .fileReadFailed:
    return .error

// Info for user actions
case .operationCancelled:
    return .info
```

### 4. Provide Recovery Actions

Always include actionable recovery suggestions:

```swift
var recoveryActions: [String] {
    switch self {
    case .gitNotInstalled:
        return [
            "Install Git from git-scm.com",
            "Or install via Homebrew: brew install git"
        ]
    }
}
```

### 5. Don't Over-Alert

Some errors shouldn't interrupt the user:

```swift
// Already running - just log it
guard !claudeMode else {
    ErrorManager.shared.handle(.claudeAlreadyRunning, presentToUser: false)
    return false
}
```

## Common Error Scenarios

### Claude CLI Not Found

**Error**: `claudeNotFound`
**Presentation**: Native alert
**Recovery**: Install instructions and settings link

### File Permission Denied

**Error**: `filePermissionDenied(path)`
**Presentation**: Native alert or inline banner
**Recovery**: System settings guidance

### Git Command Failed

**Error**: `gitCommandFailed(command, error)`
**Presentation**: Native alert
**Recovery**: Git status check and conflict resolution

### Session Creation Failed

**Error**: `sessionCreationFailed(error)`
**Presentation**: Native alert
**Recovery**: Restart app, check permissions

## Testing Errors

For testing error handling:

```swift
#if DEBUG
// Simulate errors
ErrorManager.shared.handle(.claudeNotFound)
ErrorManager.shared.handle(.filePermissionDenied("/test/file"))
#endif
```

## Migration Guide

### Converting Existing Error Handling

Before:
```swift
do {
    try file.save()
} catch {
    print("Error saving: \(error)")
}
```

After:
```swift
do {
    try file.save()
} catch {
    ErrorManager.shared.handle(error)
}
```

### Using FileOperationsHelper

Before:
```swift
do {
    let content = try String(contentsOfFile: path)
    // process content
} catch {
    print("Error: \(error)")
}
```

After:
```swift
let result = FileOperationsHelper.shared.readFile(at: path)
switch result {
case .success(let content):
    // process content
case .failure:
    // Error already handled
    return
}
```

## Future Enhancements

Potential improvements:

1. Error telemetry and analytics
2. User-configurable error notifications
3. Error grouping and deduplication
4. Automatic error reporting
5. Error recovery automation
6. Localization support

## Related Files

- `RickTerminal/Error/RTError.swift` - Error definitions
- `RickTerminal/Error/ErrorManager.swift` - Error handling service
- `RickTerminal/Error/ErrorAlertView.swift` - UI components
- `RickTerminal/Utilities/FileOperationsHelper.swift` - File operations
