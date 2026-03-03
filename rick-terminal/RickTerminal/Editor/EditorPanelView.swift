import SwiftUI

/// Editor panel with tabs for open files
struct EditorPanelView: View {
    @ObservedObject var editorManager: EditorManager
    @State private var showCloseWarning = false
    @State private var fileToClose: EditorFile?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if !editorManager.openFiles.isEmpty {
                tabBarView
            }

            // Editor content
            if let activeFile = editorManager.activeFile {
                CodeEditorView(file: activeFile)
            } else {
                emptyStateView
            }
        }
        .background(Color.rtBackgroundDark)
        .alert("Unsaved Changes", isPresented: $showCloseWarning) {
            Button("Cancel", role: .cancel) {
                fileToClose = nil
            }
            Button("Don't Save", role: .destructive) {
                if let file = fileToClose {
                    editorManager.closeFile(file, force: true)
                }
                fileToClose = nil
            }
            Button("Save") {
                if let file = fileToClose {
                    editorManager.saveFile(file)
                    editorManager.closeFile(file, force: true)
                }
                fileToClose = nil
            }
        } message: {
            if let file = fileToClose {
                Text("Do you want to save the changes you made to \"\(file.name)\"?")
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(editorManager.openFiles) { file in
                    DraggableFileTab(
                        file: file,
                        isActive: editorManager.activeFileId == file.id,
                        editorManager: editorManager,
                        onClose: { attemptCloseFile(file) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 32)
        .background(Color.rtBackgroundLight)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.rtTextSecondary.opacity(0.5))

            Text("No file open")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.rtTextSecondary)

            Text("Select a file from the browser to edit")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.rtTextSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func attemptCloseFile(_ file: EditorFile) {
        if file.hasUnsavedChanges {
            fileToClose = file
            showCloseWarning = true
        } else {
            editorManager.closeFile(file)
        }
    }
}

// MARK: - Draggable File Tab

struct DraggableFileTab: View {
    let file: EditorFile
    let isActive: Bool
    @ObservedObject var editorManager: EditorManager

    let onClose: () -> Void

    @State private var isHovering = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 6) {
            // Unsaved indicator dot
            if file.hasUnsavedChanges {
                Circle()
                    .fill(Color.rtAccentGreen)
                    .frame(width: 6, height: 6)
            }

            // File name
            Text(file.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isActive ? .rtTextPrimary : .rtTextSecondary)
                .lineLimit(1)

            // Close button - only show on hover or if tab is active
            if isHovering || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.rtTextSecondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.rtBackgroundDark : (isHovering ? Color.rtBackgroundDark.opacity(0.5) : Color.clear))
        .cornerRadius(4)
        .overlay(
            Rectangle()
                .fill(isActive ? Color.rtAccentGreen : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
        .offset(dragOffset)
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            editorManager.setActiveFile(file.id)
        }
        .middleClickGesture {
            // Middle-click to close
            onClose()
        }
        .onDrag {
            isDragging = true
            return NSItemProvider(object: file.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: TabDropDelegate(
            file: file,
            editorManager: editorManager,
            onDragEnd: { isDragging = false }
        ))
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let file: EditorFile
    let editorManager: EditorManager
    let onDragEnd: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        onDragEnd()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedIdString = info.itemProviders(for: [.text]).first else {
            return
        }

        draggedIdString.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let idString = String(data: data, encoding: .utf8),
                  let draggedId = UUID(uuidString: idString),
                  let sourceIndex = editorManager.openFiles.firstIndex(where: { $0.id == draggedId }),
                  let destinationIndex = editorManager.openFiles.firstIndex(where: { $0.id == file.id }),
                  sourceIndex != destinationIndex else {
                return
            }

            DispatchQueue.main.async {
                editorManager.moveTab(from: sourceIndex, to: destinationIndex)
            }
        }
    }

    func dropExited(info: DropInfo) {
        onDragEnd()
    }
}

// MARK: - Middle Click Support

struct MiddleClickGesture: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MiddleClickView()
        view.onMiddleClick = onMiddleClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? MiddleClickView {
            view.onMiddleClick = onMiddleClick
        }
    }

    class MiddleClickView: NSView {
        var onMiddleClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            if event.buttonNumber == 2 { // Middle mouse button
                onMiddleClick?()
            } else {
                super.mouseDown(with: event)
            }
        }
    }
}

extension View {
    func middleClickGesture(_ action: @escaping () -> Void) -> some View {
        self.background(MiddleClickGesture(onMiddleClick: action))
    }
}

// MARK: - Preview

struct EditorPanelView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = EditorManager()
        let file1 = EditorFile(
            url: URL(fileURLWithPath: "/tmp/file1.swift"),
            content: "import SwiftUI\n\nstruct View1 {}"
        )
        file1.hasUnsavedChanges = true
        let file2 = EditorFile(
            url: URL(fileURLWithPath: "/tmp/file2.swift"),
            content: "import Foundation"
        )

        manager.openFiles = [file1, file2]
        manager.activeFileId = file1.id

        return EditorPanelView(editorManager: manager)
            .frame(width: 800, height: 600)
    }
}
