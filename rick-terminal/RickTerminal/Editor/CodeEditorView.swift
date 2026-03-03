import SwiftUI

/// Code editor view with line numbers and monospace text
struct CodeEditorView: View {
    @ObservedObject var file: EditorFile
    @FocusState private var isFocused: Bool

    // Line number calculation
    private var lineCount: Int {
        file.content.isEmpty ? 1 : file.content.components(separatedBy: .newlines).count
    }

    private var lineNumberWidth: CGFloat {
        let digits = String(lineCount).count
        return CGFloat(max(3, digits)) * 10 + 16
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Line numbers
                LineNumbersView(lineCount: lineCount)
                    .frame(width: lineNumberWidth)
                    .background(Color.rtBackgroundLight)

                // Divider
                Rectangle()
                    .fill(Color.rtBorderSubtle)
                    .frame(width: 1)

                // Text editor
                TextEditor(text: Binding(
                    get: { file.content },
                    set: { newValue in
                        file.updateContent(newValue)
                    }
                ))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.rtTextPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.rtBackgroundDark)
                .focused($isFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Auto-focus editor when file opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}

// MARK: - Line Numbers View

struct LineNumbersView: View {
    let lineCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.rtTextSecondary.opacity(0.6))
                        .frame(height: 21) // Match TextEditor line height
                        .padding(.trailing, 8)
                }
            }
            .padding(.top, 8)
        }
        .disabled(true)
    }
}

// MARK: - Preview

struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleContent = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        """
        let file = EditorFile(
            url: URL(fileURLWithPath: "/tmp/sample.swift"),
            content: sampleContent
        )

        return CodeEditorView(file: file)
            .frame(width: 600, height: 400)
    }
}
