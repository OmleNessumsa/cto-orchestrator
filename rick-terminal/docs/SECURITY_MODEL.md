# RickTerminal Security Model

## Overview

RickTerminal is a macOS terminal application that integrates with Claude CLI for AI-assisted development workflows. This document describes the security model, app sandboxing configuration, and entitlements required for App Store distribution.

## App Sandbox Compliance

RickTerminal operates within the macOS App Sandbox, requesting only the minimum permissions necessary for its core functionality as a terminal emulator with AI integration.

## Entitlements Summary

| Entitlement | Justification |
|------------|---------------|
| `com.apple.security.app-sandbox` | Required for Mac App Store distribution |
| `com.apple.security.network.client` | Claude CLI communicates with Anthropic API via HTTPS |
| `com.apple.security.files.user-selected.read-write` | Users select project directories via Open/Save dialogs |
| `com.apple.security.temporary-exception.files.home-relative-path.read-only` | Shell initialization files (.zshrc, .bashrc) and Claude CLI discovery |
| `com.apple.security.temporary-exception.files.home-relative-path.read-write` | Shell history files (.zsh_history, .bash_history) and app state |
| `com.apple.security.temporary-exception.files.absolute-path.read-only` | Read-only access to /usr/local/bin, /opt/homebrew/bin for tool discovery |
| `com.apple.security.cs.allow-unsigned-executable-memory` | Required for PTY/shell process spawning |
| `com.apple.security.cs.disable-library-validation` | Spawned shell processes load user shell plugins |
| `com.apple.security.application-groups` | Shared UserDefaults for settings persistence |

## Detailed Entitlement Justification

### 1. Network Access (`com.apple.security.network.client`)

**Purpose**: Outbound HTTPS connections to Anthropic API

**Data Flow**:
- RickTerminal spawns Claude CLI as a subprocess
- Claude CLI connects to `api.anthropic.com` via HTTPS (port 443)
- All communication is encrypted with TLS 1.3

**NOT Requested**:
- `com.apple.security.network.server` - No inbound connections accepted

### 2. File System Access

#### User-Selected Files (`files.user-selected.read-write`)

Standard sandbox entitlement for file operations via NSOpenPanel/NSSavePanel. Users explicitly choose which files/directories to access through native macOS dialogs.

#### Home Directory Read Access (Temporary Exception)

**Purpose**: Shell initialization and tool discovery

**Files Accessed**:
- `~/.zshrc`, `~/.bashrc`, `~/.profile` - Shell initialization
- `~/.config/` - Tool configuration files
- `~/.local/bin/` - User-installed CLI tools (including Claude CLI)

**Security Note**: This is read-only access. The application cannot modify user dotfiles.

#### Home Directory Write Access (Temporary Exception)

**Purpose**: Terminal state persistence

**Files Written**:
- `~/.zsh_history`, `~/.bash_history` - Standard shell history
- `~/.local/share/` - XDG-compliant application data
- `~/Library/Application Support/RickTerminal/` - App-specific persistence

**Scope**: Write access is restricted to specific subdirectories, not blanket home directory access.

#### System Binary Paths (Temporary Exception)

**Purpose**: Discovery of installed CLI tools

**Paths** (Read-Only):
- `/usr/local/bin/` - Homebrew (Intel Mac)
- `/opt/homebrew/bin/` - Homebrew (Apple Silicon)
- `/opt/local/bin/` - MacPorts

**Security Note**: Read-only access for executable discovery only.

### 3. Process Execution

#### Executable Memory (`cs.allow-unsigned-executable-memory`)

**Purpose**: Terminal emulation requires spawning shell processes

**Technical Requirement**: The PTY (pseudo-terminal) implementation uses `posix_spawn()` to create shell subprocesses. This is fundamental to terminal emulator functionality.

**Implementation**:
- Uses `openpty()` for PTY pair creation
- Uses `posix_spawn()` for process creation
- All spawned processes are standard system shells (/bin/zsh, /bin/bash)

#### Library Validation Disabled (`cs.disable-library-validation`)

**Purpose**: Spawned shell processes load user-configured shell plugins

**Examples**:
- Oh My Zsh plugins
- Homebrew shell integrations
- User-installed shell extensions

**Scope**: Only affects child processes (the spawned shell), not the main application.

### 4. Application Groups

**Purpose**: Settings persistence via shared UserDefaults

**Group ID**: `com.rickportal.rickterminal`

**Data Stored**:
- Terminal appearance preferences (font, colors)
- Claude CLI configuration path
- Window layout state

## Security Architecture

```
┌──────────────────────────────────────────────────────┐
│                    RickTerminal                       │
│                  (Sandboxed App)                      │
├──────────────────────────────────────────────────────┤
│  ┌────────────────┐     ┌────────────────────────┐  │
│  │  SwiftUI GUI   │     │   Terminal Emulator    │  │
│  │                │     │   (SwiftTerm)          │  │
│  └───────┬────────┘     └───────────┬────────────┘  │
│          │                          │               │
│          │         ┌────────────────┘               │
│          ▼         ▼                                │
│  ┌─────────────────────────────────┐               │
│  │     Shell Session Manager       │               │
│  │     (posix_spawn + PTY)         │               │
│  └───────────────┬─────────────────┘               │
│                  │                                  │
└──────────────────┼──────────────────────────────────┘
                   │ PTY I/O
                   ▼
┌──────────────────────────────────────────────────────┐
│              Spawned Shell Process                   │
│              (/bin/zsh or /bin/bash)                 │
├──────────────────────────────────────────────────────┤
│                                                      │
│    ┌─────────────┐      ┌─────────────────────┐    │
│    │ Shell       │      │    Claude CLI       │    │
│    │ Commands    │      │    (User Invoked)   │    │
│    └─────────────┘      └──────────┬──────────┘    │
│                                     │               │
└─────────────────────────────────────┼───────────────┘
                                      │ HTTPS
                                      ▼
                         ┌─────────────────────────┐
                         │  api.anthropic.com      │
                         │  (External Service)     │
                         └─────────────────────────┘
```

## Data Privacy

### Data Collected
- **None**: RickTerminal does not collect, transmit, or store user data beyond local preferences

### Data Processed Locally
- Terminal session output (displayed in UI, optionally persisted to history)
- File browser state (current directory, expanded folders)
- User preferences (font size, theme, shortcuts)

### External Communication
- All external network traffic is initiated by Claude CLI, not RickTerminal directly
- Claude CLI handles its own authentication and API communication
- RickTerminal has no visibility into Claude CLI's communication with Anthropic

## Comparison to Standard Terminal Apps

RickTerminal's entitlements are comparable to or more restrictive than:

| App | Shell Execution | Network | Full Disk Access |
|-----|-----------------|---------|------------------|
| Terminal.app | Yes | Yes | Yes (default) |
| iTerm2 | Yes | Yes | Yes (configurable) |
| RickTerminal | Yes | Client only | No (scoped exceptions) |

## App Store Review Notes

### Why Terminal Apps Need These Entitlements

Terminal emulators are a unique category of macOS applications that require process spawning capabilities. Unlike typical productivity apps, terminals must:

1. **Spawn child processes**: Execute user commands via shell interpreters
2. **Access user dotfiles**: Initialize shell environment correctly
3. **Discover installed tools**: Find executables in PATH

### Entitlement Minimization Efforts

We have minimized entitlements by:

1. **No Full Disk Access**: Using scoped temporary exceptions instead of `com.apple.security.files.all`
2. **No Server Network**: Only outbound client connections
3. **Read-Only Where Possible**: System paths and shell configs are read-only
4. **Specific Write Paths**: History and state files only

### Alternative Considered

We considered distributing outside the App Store to avoid sandbox restrictions. However, we chose App Store distribution to:
- Provide users with verified, notarized software
- Enable automatic updates via App Store
- Build user trust through Apple's review process

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-02-15 | Initial security model documentation |

## Contact

For security-related questions: security@rickportal.com
