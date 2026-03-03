# RT-031: Syntax Highlighting Implementation Tasks

## Architecture Overview

See: `docs/adr/ADR-006-syntax-highlighting-library.md`

## Files Created

### New Files (Architect-Morty)
- `RickTerminal/SyntaxHighlighting/SyntaxHighlightingTypes.swift` - Core types, protocols, and theme definitions
- `RickTerminal/SyntaxHighlighting/SyntaxHighlightingService.swift` - Central service coordinating highlighters
- `RickTerminal/SyntaxHighlighting/FallbackSyntaxHighlighter.swift` - Regex-based fallback implementation

---

## Task Breakdown

### Backend-Morty Tasks

#### Task B1: Add HighlightSwift Package Dependency
**Priority**: High | **Estimated Complexity**: Low

1. Add HighlightSwift to Package.swift or via Xcode SPM:
   ```
   https://github.com/appstefan/HighlightSwift
   ```
2. Verify package resolves and builds
3. Import in SyntaxHighlightingService.swift

**Acceptance Criteria**:
- Package added and builds without errors
- Import statement works

---

#### Task B2: Implement HighlightSwiftHighlighter
**Priority**: High | **Estimated Complexity**: Medium

Create `RickTerminal/SyntaxHighlighting/HighlightSwiftHighlighter.swift`:

```swift
import Foundation
import AppKit
import HighlightSwift

/// Primary syntax highlighter using HighlightSwift (highlight.js wrapper)
final class HighlightSwiftHighlighter: SyntaxHighlighter {

    private let highlighter = Highlight()

    var engineName: String { "HighlightSwift" }

    func highlight(
        _ code: String,
        language: SyntaxLanguage?,
        theme: SyntaxTheme
    ) async throws -> HighlightResult {
        // Implementation:
        // 1. Map SyntaxLanguage to HighlightSwift language string
        // 2. Call highlighter.highlight(code, language: langString)
        // 3. Convert AttributedString to NSAttributedString
        // 4. Apply SyntaxTheme colors (map highlight.js classes to theme)
        // 5. Generate ANSI string from tokens
        // 6. Return HighlightResult
    }

    func detectLanguage(_ code: String) -> (language: SyntaxLanguage, confidence: Double)? {
        // Use HighlightSwift auto-detection
        // Map result back to SyntaxLanguage enum
    }

    func supports(_ language: SyntaxLanguage) -> Bool {
        // Return true for all languages supported by highlight.js
    }
}
```

**Acceptance Criteria**:
- Implements `SyntaxHighlighter` protocol
- Maps HighlightSwift output to Rick Terminal theme colors
- Generates both NSAttributedString and ANSI output
- Auto-detection maps correctly to `SyntaxLanguage` enum

---

#### Task B3: Create Rick Terminal CSS Theme for HighlightSwift
**Priority**: Medium | **Estimated Complexity**: Medium

Create custom highlight.js CSS theme matching Rick Terminal palette:

```css
/* RickTerminal.css */
.hljs {
  background: #0D1010;
  color: #FFFFFF;
}
.hljs-keyword { color: #7B78AA; }
.hljs-string { color: #7FFC50; }
.hljs-comment { color: #464467; }
.hljs-number { color: #2196F3; }
.hljs-type { color: #FF9F40; }
.hljs-function { color: #7FFC50; }
/* ... etc */
```

**Alternative**: Map highlight.js token classes to `SyntaxTheme` colors programmatically.

**Acceptance Criteria**:
- Colors match Rick Terminal palette exactly
- All token types have appropriate colors
- Dark mode consistent

---

#### Task B4: Integrate HighlightSwiftHighlighter into Service
**Priority**: High | **Estimated Complexity**: Low

Update `SyntaxHighlightingService.swift`:

```swift
private func initializePrimaryHighlighter() {
    do {
        self.primaryHighlighter = HighlightSwiftHighlighter()
        self.isInitialized = true
    } catch {
        // Fall back to regex highlighter
        self.primaryHighlighter = nil
        self.isInitialized = true
    }
}
```

**Acceptance Criteria**:
- Primary highlighter initializes on app launch
- Fallback works when primary fails
- Service correctly delegates to appropriate highlighter

---

#### Task B5: Add Performance Monitoring
**Priority**: Low | **Estimated Complexity**: Low

Add timing metrics to `SyntaxHighlightingService`:

1. Track average processing time
2. Log slow highlights (>100ms)
3. Track fallback percentage
4. Expose metrics for debugging

**Acceptance Criteria**:
- Processing time logged
- Statistics accessible
- No performance regression

---

### Frontend-Morty Tasks

#### Task F1: Integrate SyntaxHighlightingService into MarkdownRenderer
**Priority**: High | **Estimated Complexity**: Medium

Update `RickTerminal/Claude/MarkdownRenderer.swift`:

```swift
private let syntaxService = SyntaxHighlightingService.shared

private func renderCodeBlock(_ code: String, language: String?) -> NSAttributedString {
    let lang = language.flatMap { SyntaxLanguage(rawValue: $0.lowercased()) }
    let result = syntaxService.highlightSync(code, language: lang)

    // Use result.attributedString instead of manual highlighting
    return result.attributedString
}
```

**Acceptance Criteria**:
- Code blocks use new syntax highlighting system
- Language label from markdown fence is used
- Fallback works for unknown languages

---

#### Task F2: Integrate SyntaxHighlightingService into ANSIStyler
**Priority**: High | **Estimated Complexity**: Medium

Update `RickTerminal/Claude/ANSIStyler.swift`:

```swift
/// Style code block with syntax highlighting
static func codeBlock(_ code: String, language: String? = nil) -> String {
    let lang = language.flatMap { SyntaxLanguage(rawValue: $0.lowercased()) }
    let result = SyntaxHighlightingService.shared.highlightSync(code, language: lang)

    var output = ""
    if let langName = lang?.displayName ?? language {
        output += colorRGB("[\(langName)]", r: rtMuted.r, g: rtMuted.g, b: rtMuted.b) + "\n"
    }
    output += result.ansiString
    return output
}
```

**Acceptance Criteria**:
- Terminal code blocks have syntax highlighting
- Colors match Rick Terminal theme
- ANSI codes render correctly in SwiftTerm

---

#### Task F3: Update CodeEditorView with Syntax Highlighting
**Priority**: Medium | **Estimated Complexity**: High

Update `RickTerminal/Editor/CodeEditorView.swift`:

1. Add syntax highlighting to the text editor
2. Detect language from file extension
3. Re-highlight on content changes (debounced)
4. Show language indicator

```swift
struct CodeEditorView: View {
    @StateObject private var syntaxService = SyntaxHighlightingService.shared
    @State private var detectedLanguage: SyntaxLanguage?

    // Use NSTextView with attributed text for highlighting
}
```

**Acceptance Criteria**:
- File content is syntax highlighted
- Language detected from filename
- Re-highlighting doesn't block UI
- Performance acceptable on 1000+ line files

---

#### Task F4: Add Language Detection UI Indicator
**Priority**: Low | **Estimated Complexity**: Low

Show detected language in CodeEditorView header:

```swift
HStack {
    Text(filename)
    Spacer()
    if let lang = detectedLanguage {
        Text(lang.displayName)
            .font(.caption)
            .foregroundColor(.rtTextSecondary)
    }
}
```

**Acceptance Criteria**:
- Language badge shows in editor header
- Updates when file changes
- Matches app styling

---

#### Task F5: Add Syntax Highlighting Settings
**Priority**: Low | **Estimated Complexity**: Medium

Add settings to `ClaudeSettingsView.swift`:

1. Enable/disable syntax highlighting toggle
2. Theme selection (future: multiple themes)

**Acceptance Criteria**:
- Setting persists
- Toggle immediately affects output
- Accessible from settings panel

---

## Testing Tasks

#### Task T1: Unit Tests for SyntaxHighlightingTypes
- Test `SyntaxLanguage.fromExtension()` with all supported extensions
- Test `SyntaxLanguage.fromFilename()` with special filenames
- Test `SyntaxTheme` color retrieval

#### Task T2: Unit Tests for FallbackSyntaxHighlighter
- Test highlighting for each supported language
- Test language detection accuracy
- Test edge cases (empty code, very long code, special characters)

#### Task T3: Integration Tests
- Test MarkdownRenderer with code blocks
- Test ANSIStyler code blocks
- Test CodeEditorView highlighting

#### Task T4: Performance Tests
- Benchmark highlighting time for 100/500/1000/5000 line files
- Verify no UI blocking on large files
- Test memory usage

---

## Definition of Done (RT-031)

- [ ] HighlightSwift package integrated
- [ ] All 7 required languages highlighted correctly: Swift, Python, JavaScript, TypeScript, JSON, YAML, Markdown
- [ ] Plus bonus languages: Bash, Go, Rust
- [ ] Language auto-detected from file extension
- [ ] Theme colors match Rick Terminal palette
- [ ] Performance acceptable on 1000+ line files (<100ms)
- [ ] MarkdownRenderer uses new system
- [ ] ANSIStyler uses new system
- [ ] CodeEditorView has syntax highlighting
- [ ] Unit tests pass
- [ ] No regressions in existing functionality

---

## Dependencies

```
RT-031 (Syntax Highlighting)
├── No blocking dependencies
└── Related: RT-005 (IDE Features Epic)
```

## Risks

| Risk | Mitigation |
|------|------------|
| HighlightSwift performance issues | FallbackSyntaxHighlighter always available |
| JavaScriptCore memory usage | Monitor and optimize if needed |
| Theme mismatch | Custom CSS or programmatic mapping |

---

## Team Updates

**Messages to team**:
- @backend-morty: Start with Task B1 (add package dependency), then B2 (implement highlighter). The interfaces and types are ready in SyntaxHighlightingTypes.swift
- @frontend-morty: Wait for B4 to complete, then start F1 (MarkdownRenderer) and F2 (ANSIStyler). You can start F3 (CodeEditorView) in parallel using the fallback highlighter.
- @*: The FallbackSyntaxHighlighter is fully functional and can be used immediately for development and testing

**Decisions made**:
- Selected HighlightSwift over tree-sitter (simpler, sufficient for read-only display)
- Hybrid approach: HighlightSwift primary, regex fallback
- Theme colors defined in SyntaxTheme.rickTerminal
- 20 languages supported (10 with detailed patterns, 10 with basic)

**Blocked on**:
- Nothing - architecture complete, implementation can begin
