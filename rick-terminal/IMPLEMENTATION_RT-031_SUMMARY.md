# RT-031: Syntax Highlighting - Architecture Design Complete

## Summary

Architect-Morty has completed the system design for syntax highlighting integration in Rick Terminal. The design follows a hybrid approach using HighlightSwift (highlight.js wrapper) as the primary engine with a robust regex-based fallback.

## Files Created

| File | Purpose |
|------|---------|
| `docs/adr/ADR-006-syntax-highlighting-library.md` | Architecture Decision Record documenting library selection |
| `RickTerminal/SyntaxHighlighting/SyntaxHighlightingTypes.swift` | Core types: `SyntaxLanguage`, `SyntaxToken`, `HighlightResult`, `SyntaxTheme`, `SyntaxHighlighter` protocol |
| `RickTerminal/SyntaxHighlighting/SyntaxHighlightingService.swift` | Central singleton service coordinating primary/fallback highlighters |
| `RickTerminal/SyntaxHighlighting/FallbackSyntaxHighlighter.swift` | Regex-based implementation supporting 20 languages |
| `IMPLEMENTATION_RT-031_TASKS.md` | Detailed task breakdown for backend-morty and frontend-morty |

## Architecture Decisions

### Library Selection: HighlightSwift
- **Why**: 50+ languages, auto-detection, SwiftUI-ready, AttributedString output
- **Alternative considered**: tree-sitter (overkill for read-only display)
- **Fallback**: Custom regex-based highlighter (always available)

### Supported Languages (20 total)
**Required (7)**: Swift, Python, JavaScript, TypeScript, JSON, YAML, Markdown
**Bonus (13)**: Bash, Go, Rust, HTML, CSS, SQL, Ruby, Java, Kotlin, C++, C, C#, PHP

### Theme Integration
Rick Terminal palette mapped to syntax token types:
- **Keywords**: Purple (#7B78AA)
- **Strings/Functions**: Green (#7FFC50)
- **Comments**: Muted (#464467)
- **Numbers/Constants**: Blue (#2196F3)
- **Types/Tags**: Orange (#FF9F40)
- **Plain text**: White (#FFFFFF)

## Integration Points

```
                    SyntaxHighlightingService
                            │
            ┌───────────────┼───────────────┐
            │               │               │
    MarkdownRenderer   ANSIStyler    CodeEditorView
    (NSAttributedString)  (ANSI codes)   (Editor panel)
```

## Task Assignments

### Backend-Morty (5 tasks)
1. Add HighlightSwift package dependency
2. Implement `HighlightSwiftHighlighter` adapter
3. Create Rick Terminal CSS theme for highlight.js
4. Integrate highlighter into service
5. Add performance monitoring

### Frontend-Morty (5 tasks)
1. Integrate service into `MarkdownRenderer`
2. Integrate service into `ANSIStyler`
3. Add syntax highlighting to `CodeEditorView`
4. Add language detection UI indicator
5. Add settings toggle

## What's Ready to Use Now

The `FallbackSyntaxHighlighter` is fully functional and can be used immediately:

```swift
let service = SyntaxHighlightingService.shared

// Async highlight
let result = await service.highlight(code, language: .swift)
print(result.attributedString) // For UI
print(result.ansiString)       // For terminal

// Sync highlight (small snippets)
let quickResult = service.highlightSync(code, filename: "main.swift")

// Auto-detect language
if let detected = service.detectLanguage(code) {
    print("\(detected.language.displayName): \(detected.confidence)")
}
```

## Open Questions

None - architecture is complete and implementation can proceed.

---

**Status**: completed
**Architect-Morty out.** 🔧
