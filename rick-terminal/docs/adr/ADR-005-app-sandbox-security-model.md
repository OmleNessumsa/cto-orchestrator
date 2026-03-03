# ADR-005: App Sandbox Security Model

## Status
Accepted

## Date
2024-02-15

## Context

RickTerminal is a macOS terminal application targeting Mac App Store distribution. The App Store requires App Sandbox compliance, which restricts application capabilities to protect user data and system integrity.

Terminal emulators present unique challenges for sandboxing because they fundamentally require:
1. Spawning child processes (shells)
2. Reading user shell configuration files
3. Network access for integrated tools (Claude CLI)
4. Persistent storage for shell history and application state

We need to configure the minimum set of entitlements that enable full terminal functionality while maintaining App Store eligibility.

## Decision

We will implement a scoped sandbox configuration with the following entitlement categories:

### 1. Network: Client-Only

```xml
<key>com.apple.security.network.client</key>
<true/>
```

**Rationale**: Claude CLI requires outbound HTTPS connections to Anthropic API. We explicitly do NOT request server capabilities (`network.server`) as RickTerminal never accepts inbound connections.

### 2. File System: Layered Access Model

We implement a three-tier file access model:

**Tier 1 - User-Selected (Standard Sandbox)**
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```
Users explicitly grant access via Open/Save dialogs.

**Tier 2 - Home Directory (Temporary Exceptions)**
```xml
<key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
<array><string>/</string></array>

<key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
<array>
    <string>/.zsh_history</string>
    <string>/.bash_history</string>
    <string>/.local/share/</string>
    <string>/Library/Application Support/RickTerminal/</string>
</array>
```

Read access to home directory for shell initialization; scoped write access for history and app state only.

**Tier 3 - System Paths (Absolute Path Exceptions)**
```xml
<key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
<array>
    <string>/usr/local/bin/</string>
    <string>/opt/homebrew/bin/</string>
    <string>/opt/local/bin/</string>
</array>
```

Read-only access to Homebrew/MacPorts installation directories for tool discovery.

### 3. Process Execution

```xml
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>

<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

**Rationale**: PTY-based terminal emulation requires `posix_spawn()` to create shell subprocesses. Spawned shells load user-configured plugins (Oh My Zsh, etc.) which requires disabled library validation for child processes only.

### 4. Application Groups

```xml
<key>com.apple.security.application-groups</key>
<array><string>com.rickportal.rickterminal</string></array>
```

**Rationale**: Shared UserDefaults container for settings persistence across app sessions.

## Alternatives Considered

### Alternative 1: Full Disk Access

**Option**: Request `com.apple.security.files.all`

**Rejected because**:
- Overly broad permissions
- Likely App Store rejection
- Erodes user trust
- Our scoped exceptions achieve the same functionality

### Alternative 2: Non-App Store Distribution

**Option**: Distribute via direct download, avoiding sandbox requirements

**Rejected because**:
- Loses automatic updates via App Store
- Loses notarization trust signals
- Requires self-managed code signing infrastructure
- Users increasingly prefer App Store for security

### Alternative 3: Minimal Entitlements + Prompt for Access

**Option**: Start with minimal entitlements, prompt users for access at runtime

**Rejected because**:
- Poor UX for terminal app (many access prompts)
- Shell initialization would fail without immediate dotfile access
- Breaks "just works" expectation for terminal apps

## Consequences

### Positive
- App Store eligible with documented justifications
- Minimal attack surface (no server network, scoped file access)
- Shell sessions work correctly including user customizations
- Claude CLI integration functions as expected

### Negative
- Temporary exceptions may require re-justification in future macOS versions
- Some advanced shell configurations may require additional entitlements
- Cannot access files outside scoped paths without user selection

### Neutral
- Security model comparable to existing App Store terminal apps
- Documentation overhead for App Store review

## Implementation

1. Update `RickTerminal.entitlements` with the decided configuration
2. Create `docs/SECURITY_MODEL.md` for App Store review reference
3. Test shell session functionality in sandboxed environment
4. Verify Claude CLI network access functions correctly

## References

- [Apple App Sandbox Design Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [Entitlement Key Reference](https://developer.apple.com/documentation/bundleresources/entitlements)
- [WWDC 2012: The App Sandbox](https://developer.apple.com/videos/play/wwdc2012/206/)
