# Contributing to Rick Terminal

Thank you for your interest in contributing to Rick Terminal. This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Architecture Guidelines](#architecture-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)

## Code of Conduct

Be excellent to each other. We're all here to build great software.

## Getting Started

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Git

### Clone and Build

```bash
git clone https://github.com/your-org/rick-terminal.git
cd rick-terminal
open RickTerminal.xcodeproj
```

Build with `Cmd+B`, run with `Cmd+R`.

## Development Setup

### Dependencies

Rick Terminal uses Swift Package Manager for dependencies. Xcode resolves these automatically:

- **SwiftTerm** - Terminal emulation
- No other external dependencies (by design)

### Project Structure

```
rick-terminal/
├── RickTerminal/           # Main application source
│   ├── Agent/              # Agent visualization
│   ├── Claude/             # Claude CLI integration
│   ├── Editor/             # Code editor panel
│   ├── Error/              # Error handling
│   ├── FileBrowser/        # File tree navigation
│   ├── Kanban/             # Kanban board system
│   ├── Keyboard/           # Shortcut management
│   ├── Preferences/        # Settings views
│   ├── SyntaxHighlighting/ # Code highlighting
│   └── Utilities/          # Helper functions
├── RickTerminalTests/      # Unit tests
├── docs/                   # Documentation
│   └── adr/                # Architecture Decision Records
└── RickTerminal.xcodeproj  # Xcode project
```

## Code Style

### Swift Conventions

Follow Apple's [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

**Naming**:
- Types and protocols: `UpperCamelCase`
- Functions, variables, properties: `lowerCamelCase`
- Constants: `lowerCamelCase` (not `SCREAMING_SNAKE_CASE`)

**Formatting**:
- 4-space indentation
- Opening braces on same line
- One blank line between function definitions
- No trailing whitespace

```swift
// Good
class KanbanCard: Identifiable {
    let id: UUID
    var title: String

    init(title: String) {
        self.id = UUID()
        self.title = title
    }

    func updateTitle(_ newTitle: String) {
        title = newTitle
    }
}

// Bad
class kanban_card : Identifiable
{
    let ID: UUID
    var Title: String
}
```

### SwiftUI Conventions

**View structure**:
```swift
struct MyView: View {
    // MARK: - Properties (State, Bindings, Environment)
    @State private var isExpanded = false
    @Binding var selection: UUID?
    @EnvironmentObject var manager: SomeManager

    // MARK: - Body
    var body: some View {
        VStack {
            headerSection
            contentSection
        }
    }

    // MARK: - View Components
    private var headerSection: some View {
        Text("Header")
    }

    private var contentSection: some View {
        Text("Content")
    }

    // MARK: - Methods
    private func handleTap() {
        isExpanded.toggle()
    }
}
```

### File Organization

Use `// MARK: -` comments to organize code sections:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - View Components (for SwiftUI)
```

### Imports

Order imports alphabetically, system frameworks first:

```swift
import AppKit
import Combine
import Foundation
import SwiftUI

import SwiftTerm  // Third-party
```

## Architecture Guidelines

### Core Principles

1. **Separation of Concerns** - Keep UI, business logic, and data separate
2. **Observable Pattern** - Use `@Published` and Combine for reactive updates
3. **Thread Safety** - All model mutations through serial dispatch queues
4. **Value Types** - Prefer structs for data models, classes for state management

### Adding New Features

1. **Check existing patterns** - Review similar features first
2. **Consider ADRs** - Significant decisions need Architecture Decision Records
3. **Keep it minimal** - Only add what's needed for the current feature
4. **Thread safety** - Ensure updates are main-thread safe for UI

### Creating Architecture Decision Records

For significant architectural changes, create an ADR in `docs/adr/`:

```markdown
# ADR-XXX: Title

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
Why is this decision needed?

## Decision
What is the change?

## Consequences
What are the trade-offs?
```

### Module Guidelines

**Claude Module** (`RickTerminal/Claude/`):
- Parsing logic for Claude CLI output
- Event emission via Combine publishers
- No direct UI dependencies

**Kanban Module** (`RickTerminal/Kanban/`):
- Data models (`KanbanCard`, `KanbanColumn`, `KanbanBoard`)
- Observable state management
- Views in `Views/` subdirectory

**Agent Module** (`RickTerminal/Agent/`):
- Real-time tool usage visualization
- Aggregates events from Claude parser

## Pull Request Process

### Before Submitting

1. **Create a branch**: `git checkout -b feature/your-feature-name`
2. **Write tests**: All new functionality needs tests
3. **Run tests**: `xcodebuild test -scheme RickTerminal`
4. **Update docs**: Add documentation for new features
5. **Check formatting**: No trailing whitespace, consistent style

### PR Requirements

- **Title**: Clear, descriptive (e.g., "Add card drag-and-drop support")
- **Description**: Explain what and why
- **Tests**: All tests passing
- **No warnings**: Zero compiler warnings
- **Documentation**: Update relevant docs

### Review Process

1. Submit PR against `main` branch
2. Automated tests run via CI
3. At least one maintainer review required
4. Address feedback
5. Squash merge when approved

### Commit Messages

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
```
feat(kanban): add card drag-and-drop support
fix(parser): handle malformed TodoWrite output
docs(readme): update build instructions
refactor(agent): extract status aggregation logic
```

## Testing Requirements

### Unit Tests

All new functionality needs unit tests. Place tests in `RickTerminalTests/`.

```swift
import XCTest
@testable import RickTerminal

final class KanbanCardTests: XCTestCase {
    func testCardCreation() {
        let card = KanbanCard(title: "Test Task")
        XCTAssertEqual(card.title, "Test Task")
        XCTAssertEqual(card.status, .backlog)
    }

    func testStatusUpdate() {
        var card = KanbanCard(title: "Test")
        card.status = .inProgress
        XCTAssertEqual(card.status, .inProgress)
    }
}
```

### Running Tests

```bash
# All tests via Xcode
xcodebuild test -scheme RickTerminal -destination 'platform=macOS'

# Specific test class
xcodebuild test -scheme RickTerminal -only-testing:RickTerminalTests/KanbanCardTests
```

### Test Naming

Use descriptive names that explain what's being tested:

```swift
func testTodoWriteParser_ParsesValidOutput_ReturnsCorrectPayload()
func testKanbanBoard_MoveCard_UpdatesColumnCorrectly()
func testClaudePathDetector_InvalidPath_ReturnsFalse()
```

### Code Coverage

Aim for meaningful coverage, not 100%. Focus on:
- Business logic
- Edge cases
- Error handling

## Documentation

### Code Comments

Use comments to explain **why**, not **what**:

```swift
// Good - explains reasoning
// Use SHA256 hash for card identity to enable content-based deduplication
let contentHash = content.sha256()

// Bad - describes obvious code
// Create a new UUID
let id = UUID()
```

### Documentation Files

Update these when relevant:

| File | Purpose |
|------|---------|
| `README.md` | Project overview, getting started |
| `CONTRIBUTING.md` | This file |
| `docs/SECURITY_MODEL.md` | Security and entitlements |
| `docs/KANBAN_INTEGRATION_GUIDE.md` | Kanban system details |
| `docs/adr/*.md` | Architecture decisions |

### API Documentation

For public APIs, use Swift documentation comments:

```swift
/// Parses Claude CLI output and emits tool events.
///
/// The parser maintains internal state to handle streaming output
/// and emits events via Combine publishers.
///
/// - Parameter chunk: Raw output chunk from Claude CLI
/// - Note: Call `reset()` between sessions
class ClaudeOutputParser {
    /// Processes an output chunk and emits any detected events.
    ///
    /// - Parameter chunk: The raw string output to parse
    func process(_ chunk: String) {
        // ...
    }
}
```

## Questions?

- Check existing issues and discussions
- Review the ADRs for architectural context
- Open an issue for larger questions

---

*Wubba lubba dub dub! - Rick Sanchez, CTO*
