# ADR-006: Syntax Highlighting Library Selection

## Status
**Proposed** - Pending implementation

## Date
2026-02-15

## Context

Rick Terminal (RT-031) requires syntax highlighting for code blocks displayed in:
1. **Terminal output** - Claude CLI responses containing code (via ANSI styling)
2. **Code Editor panel** - CodeEditorView for file editing (via NSAttributedString)
3. **Markdown rendering** - MarkdownRenderer for rich text (via NSAttributedString)

### Requirements
- Support at least 5 languages: Swift, Python, JavaScript, TypeScript, JSON, YAML, Markdown
- Auto-detect language from file extension
- Theme colors consistent with Rick Terminal palette
- Acceptable performance on large files (1000+ lines)
- Integration with both ANSI-based terminal output and NSAttributedString-based UI

### Current State
The codebase already has:
- `MarkdownRenderer.swift` - Basic regex-based syntax highlighting for Swift, JS, TS, Python, Rust, Go
- `ANSIStyler.swift` - ANSI escape code generator with Rick Terminal colors
- `Color+Theme.swift` - Theme color definitions (rtAccentPurple, rtAccentGreen, etc.)

### Options Considered

#### Option 1: HighlightSwift (highlight.js wrapper)
**Package:** [appstefan/HighlightSwift](https://github.com/appstefan/HighlightSwift)

| Pros | Cons |
|------|------|
| 50+ languages supported | JavaScriptCore dependency |
| 30 built-in themes | Theme customization via CSS |
| SwiftUI integration | No direct ANSI output support |
| Automatic language detection | May have latency on large files |
| Auto Dark Mode sync | |
| Returns AttributedString directly | |

#### Option 2: ChimeHQ Neon + tree-sitter
**Packages:** [ChimeHQ/Neon](https://github.com/ChimeHQ/Neon) + [tree-sitter/swift-tree-sitter](https://github.com/tree-sitter/swift-tree-sitter)

| Pros | Cons |
|------|------|
| Incremental parsing (fast for edits) | Complex setup per language |
| Accurate AST-based highlighting | Requires grammar files per language |
| Hybrid sync/async API | Higher learning curve |
| Designed for large documents | More dependencies |
| NSTextView/UITextView integration | |

#### Option 3: Enhanced Custom Implementation
**Approach:** Extend existing MarkdownRenderer with modular language-specific tokenizers

| Pros | Cons |
|------|------|
| No external dependencies | Regex-based (less accurate) |
| Full control over output format | More maintenance burden |
| Works with both ANSI and NSAttributedString | Limited language detection |
| Already partially implemented | |
| Lightweight | |

#### Option 4: Hybrid Approach (Recommended)
**Approach:** HighlightSwift for accuracy + Custom ANSI bridge

| Pros | Cons |
|------|------|
| Accurate highlighting via highlight.js | JavaScriptCore dependency |
| Reuse themes across terminal/UI | Requires AttributedString → ANSI conversion |
| Language auto-detection built-in | |
| SwiftUI-ready | |
| Fallback to existing implementation | |

## Decision

**Recommended: Option 4 - Hybrid Approach with HighlightSwift**

Rationale:
1. **Accuracy** - highlight.js provides production-grade tokenization for 50+ languages
2. **Simplicity** - Single package vs multi-package tree-sitter setup
3. **Compatibility** - AttributedString output integrates with existing MarkdownRenderer
4. **Flexibility** - Can convert AttributedString to ANSI codes for terminal output
5. **Fallback** - Keep enhanced custom implementation as fallback for unsupported scenarios
6. **Performance** - Good enough for typical code blocks; tree-sitter overkill for read-only display

### Language Priority
| Language | Extension | Detection Pattern |
|----------|-----------|-------------------|
| Swift | .swift | `import Foundation\|UIKit\|SwiftUI` |
| Python | .py | `def \|import \|from \|class ` |
| JavaScript | .js | `const \|let \|function\|=>` |
| TypeScript | .ts, .tsx | `interface \|type \|: string\|: number` |
| JSON | .json | `^\s*[\{\[]` |
| YAML | .yaml, .yml | `^[\w-]+:\s` |
| Markdown | .md | `^#\|^\*\*\|^\-\s` |
| Bash/Shell | .sh, .bash | `^#!\|^\$\s` |
| Go | .go | `package \|func \|import "` |
| Rust | .rs | `fn \|let mut\|impl\|struct` |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SyntaxHighlightingService                    │
│                        (Singleton)                              │
├─────────────────────────────────────────────────────────────────┤
│  + highlight(code: String, language: Language?) → HighlightResult│
│  + detectLanguage(code: String, filename: String?) → Language?  │
│  + availableThemes() → [SyntaxTheme]                            │
│  + setTheme(_ theme: SyntaxTheme)                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
        ┌───────────────────┐   ┌───────────────────┐
        │  HighlightSwift   │   │ FallbackHighlighter│
        │   (Primary)       │   │   (Regex-based)   │
        └───────────────────┘   └───────────────────┘
                    │
                    ▼
        ┌───────────────────────────────────────────┐
        │           HighlightResult                 │
        ├───────────────────────────────────────────┤
        │  + attributedString: NSAttributedString   │
        │  + ansiString: String                     │
        │  + tokens: [SyntaxToken]                  │
        │  + detectedLanguage: Language?            │
        └───────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│ MarkdownRenderer │   │  ANSIStyler   │
│ (UI panels)      │   │  (Terminal)   │
└───────────────┘       └───────────────┘
```

## Theme Mapping

Rick Terminal palette mapped to syntax highlighting roles:

| Syntax Role | Color | Hex | RGB |
|------------|-------|-----|-----|
| Keyword | Purple | #7B78AA | (123, 120, 170) |
| String | Green | #7FFC50 | (127, 252, 80) |
| Comment | Muted | #464467 | (70, 68, 103) |
| Number | Blue | #2196F3 | (33, 150, 243) |
| Type/Class | Orange | #FF9F40 | (255, 159, 64) |
| Function | Green | #7FFC50 | (127, 252, 80) |
| Variable | White | #FFFFFF | (255, 255, 255) |
| Operator | Secondary | #9CA3AF | (156, 163, 175) |
| Property | Purple Light | #9B99C4 | (155, 153, 196) |
| Background | Dark | #0D1010 | (13, 16, 16) |
| Code Block BG | Secondary | #1E3738 | (30, 55, 56) |

## Consequences

### Positive
- Rich syntax highlighting for 50+ languages
- Consistent theming across terminal and UI
- Automatic language detection reduces user friction
- SwiftUI integration for future CodeEditorView improvements
- Fallback ensures graceful degradation

### Negative
- JavaScriptCore dependency increases binary size (~2-3MB)
- Initial load may have slight delay on first highlight
- Custom theme requires CSS knowledge or mapping layer

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Package becomes unmaintained | Fallback highlighter always available |
| Performance issues on large files | Async highlighting with loading state |
| Theme mismatch | Create custom CSS theme matching Rick Terminal |

## Implementation Tasks

See: RT-031 task breakdown for backend-morty and frontend-morty assignments.

## References

- [HighlightSwift](https://github.com/appstefan/HighlightSwift)
- [ChimeHQ/Neon](https://github.com/ChimeHQ/Neon)
- [highlight.js](https://highlightjs.org/)
- [tree-sitter](https://tree-sitter.github.io/)
