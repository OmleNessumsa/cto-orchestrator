import SwiftUI

/// File browser sidebar with tree view
struct FileBrowserView: View {
    @StateObject private var fileTreeManager = FileTreeManager()
    @EnvironmentObject private var sessionManager: ShellSessionManager
    @EnvironmentObject private var editorManager: EditorManager

    @State private var showNewFileSheet = false
    @State private var showNewFolderSheet = false
    @State private var newItemName = ""
    @State private var errorMessage: String?
    @State private var triggerRenameNode: FileNode?
    @State private var triggerDeleteNode: FileNode?
    @State private var isLaunchingClaude = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            // Tree View
            if let rootNode = fileTreeManager.rootNode {
                ScrollView {
                    FileTreeView(
                        node: rootNode,
                        fileTreeManager: fileTreeManager,
                        level: 0,
                        triggerRenameNode: $triggerRenameNode,
                        triggerDeleteNode: $triggerDeleteNode
                    )
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
            } else {
                emptyStateView
            }
        }
        .onAppear {
            // Connect file opening to editor
            fileTreeManager.onOpenFile = { url in
                editorManager.openFile(url: url)
            }

            // Connect keyboard shortcut callbacks
            fileTreeManager.onRenameRequested = { node in
                triggerRenameNode = node
            }
            fileTreeManager.onDeleteRequested = { node in
                triggerDeleteNode = node
            }
        }
        .sheet(isPresented: $showNewFileSheet) {
            newItemSheet(title: "New File", placeholder: "Untitled.txt") { name in
                createNewFile(name: name)
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            newItemSheet(title: "New Folder", placeholder: "Untitled") { name in
                createNewFolder(name: name)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        // Keyboard shortcut handlers
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
            openFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFile)) { _ in
            showNewFileSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFolder)) { _ in
            showNewFolderSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameFile)) { _ in
            if let selected = fileTreeManager.selectedNode {
                fileTreeManager.notifyRenameRequested(selected)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .duplicateFile)) { _ in
            if let selected = fileTreeManager.selectedNode {
                errorMessage = fileTreeManager.duplicate(selected)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteFile)) { _ in
            if let selected = fileTreeManager.selectedNode {
                fileTreeManager.notifyDeleteRequested(selected)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .revealInFinder)) { _ in
            if let selected = fileTreeManager.selectedNode {
                fileTreeManager.revealInFinder(selected)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FILE BROWSER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.rtAccentGreen)

                Spacer()

                // Open folder button
                Button(action: { openFolder() }) {
                    Image(systemName: "folder")
                        .foregroundColor(.rtAccentGreen)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Open Folder...")

                // New file button
                Menu {
                    Button("New File...") {
                        showNewFileSheet = true
                    }
                    Button("New Folder...") {
                        showNewFolderSheet = true
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.rtAccentGreen)
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("New file or folder")

                // Hidden files toggle
                Button(action: { fileTreeManager.toggleHidden() }) {
                    Image(systemName: fileTreeManager.showHidden ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(.rtAccentGreen)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(fileTreeManager.showHidden ? "Hide hidden files" : "Show hidden files")

                // Reload button
                Button(action: { fileTreeManager.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.rtAccentGreen)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Reload file tree")

                // Open in Finder
                Button(action: { openInFinder() }) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.rtAccentGreen)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
            }
            .padding(8)
            .background(Color.rtBackgroundDark.opacity(0.5))

            // Current directory path
            Text(fileTreeManager.currentDirectory.path)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.rtTextSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.rtBackgroundSecondary.opacity(0.3))
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Rick-style icon
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.rtAccentGreen.opacity(0.8))

            Text("Open a Project")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.rtTextPrimary)

            Text("Select a project folder to start working with Rick")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.rtTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: { openFolder() }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("Open Project Folder")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.rtAccentGreen)
                .foregroundColor(.rtBackgroundDark)
                .cornerRadius(8)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
            }
            .buttonStyle(.plain)

            // Hint for CTO projects
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text("CTO projects (.cto/) auto-launch Claude + Rick skill")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(.rtTextSecondary.opacity(0.7))
            .padding(.top, 8)

            // Loading indicator when launching Claude
            if isLaunchingClaude {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Launching Claude...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.rtAccentGreen)
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder to open"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            openProject(at: url)
        }
    }

    /// Open a project at the specified URL
    private func openProject(at url: URL) {
        // 1. Update file browser root
        fileTreeManager.changeRoot(to: url)

        // 2. Change terminal working directory
        guard let session = sessionManager.getActiveSession() else { return }
        session.sendInput("cd \"\(url.path)\" && clear\n")

        // 3. Check if this is a CTO project and auto-launch Claude
        if isCTOProject(url) {
            launchClaudeWithSkill(session: session)
        }
    }

    /// Check if a directory is a CTO project (has .cto/ folder)
    private func isCTOProject(_ url: URL) -> Bool {
        let ctoDir = url.appendingPathComponent(".cto")
        return FileManager.default.fileExists(atPath: ctoDir.path)
    }

    /// Launch Claude CLI and send the CTO orchestrator skill command
    private func launchClaudeWithSkill(session: ShellSession) {
        // Don't launch if already in Claude mode
        guard !sessionManager.claudeMode else {
            // Already in Claude mode, just send the skill command
            sessionManager.sendInput("/cto-orchestrator\n")
            return
        }

        isLaunchingClaude = true

        // Launch Claude
        let launched = sessionManager.launchClaude()
        guard launched else {
            isLaunchingClaude = false
            return
        }

        // Wait for Claude to be ready, then send skill command
        // Claude typically shows its prompt within 2-3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.sessionManager.sendInput("/cto-orchestrator\n")
            self.isLaunchingClaude = false
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileTreeManager.currentDirectory])
    }

    private func createNewFile(name: String) {
        errorMessage = fileTreeManager.createFile(in: fileTreeManager.selectedNode, name: name)
    }

    private func createNewFolder(name: String) {
        errorMessage = fileTreeManager.createDirectory(in: fileTreeManager.selectedNode, name: name)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func newItemSheet(title: String, placeholder: String, onCreate: @escaping (String) -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.rtTextPrimary)

            TextField(placeholder, text: $newItemName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)

            HStack(spacing: 12) {
                Button("Cancel") {
                    newItemName = ""
                    showNewFileSheet = false
                    showNewFolderSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    guard !newItemName.isEmpty else { return }
                    onCreate(newItemName)
                    newItemName = ""
                    showNewFileSheet = false
                    showNewFolderSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newItemName.isEmpty)
            }
        }
        .padding(24)
        .background(Color.rtBackgroundLight)
        .cornerRadius(8)
    }
}

// MARK: - File Tree View

struct FileTreeView: View {
    @ObservedObject var node: FileNode
    @ObservedObject var fileTreeManager: FileTreeManager
    let level: Int
    @Binding var triggerRenameNode: FileNode?
    @Binding var triggerDeleteNode: FileNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current node
            FileTreeItemView(
                node: node,
                fileTreeManager: fileTreeManager,
                level: level,
                triggerRenameNode: $triggerRenameNode,
                triggerDeleteNode: $triggerDeleteNode
            )

            // Children (if expanded and loaded)
            if node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeView(
                        node: child,
                        fileTreeManager: fileTreeManager,
                        level: level + 1,
                        triggerRenameNode: $triggerRenameNode,
                        triggerDeleteNode: $triggerDeleteNode
                    )
                }
            }

            // Loading indicator
            if node.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)

                    Text("Loading...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)
                }
                .padding(.leading, CGFloat((level + 1) * 16 + 20))
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - File Tree Item View

struct FileTreeItemView: View {
    @ObservedObject var node: FileNode
    @ObservedObject var fileTreeManager: FileTreeManager
    let level: Int
    @Binding var triggerRenameNode: FileNode?
    @Binding var triggerDeleteNode: FileNode?

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renamingText = ""
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 4) {
            // Expand/collapse chevron for directories
            if node.isDirectory {
                Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.rtTextSecondary)
                    .frame(width: 12, height: 12)
            } else {
                Spacer()
                    .frame(width: 12)
            }

            // Icon
            Image(systemName: node.icon)
                .foregroundColor(Color(hex: node.iconColor.light))
                .font(.system(size: 12))
                .frame(width: 16, height: 16)

            // Name (editable when renaming)
            if isRenaming {
                TextField("", text: $renamingText, onCommit: {
                    performRename()
                })
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.rtTextPrimary)
                .onAppear {
                    renamingText = node.name
                }
                .onExitCommand {
                    cancelRename()
                }
            } else {
                Text(node.name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(
                        fileTreeManager.selectedNode?.id == node.id
                            ? .rtAccentGreen
                            : (node.isHidden ? .rtTextSecondary.opacity(0.6) : .rtTextPrimary)
                    )
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.leading, CGFloat(level * 16 + 4))
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(backgroundForNode)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handleTap()
        }
        .contextMenu {
            contextMenuItems
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .alert("Delete \(node.isDirectory ? "folder" : "file")?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(node.name)'? This action cannot be undone.")
        }
        // Keyboard shortcuts (when selected)
        .onDeleteCommand {
            if fileTreeManager.selectedNode?.id == node.id {
                showDeleteConfirmation = true
            }
        }
        .onChange(of: triggerRenameNode?.id) { _ in
            if let triggerNode = triggerRenameNode, triggerNode.id == node.id {
                startRename()
                // Reset trigger after handling
                DispatchQueue.main.async {
                    triggerRenameNode = nil
                }
            }
        }
        .onChange(of: triggerDeleteNode?.id) { _ in
            if let triggerNode = triggerDeleteNode, triggerNode.id == node.id {
                showDeleteConfirmation = true
                // Reset trigger after handling
                DispatchQueue.main.async {
                    triggerDeleteNode = nil
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundForNode: Color {
        if fileTreeManager.selectedNode?.id == node.id {
            return Color.rtAccentGreen.opacity(0.15)
        } else if isHovered {
            return Color.rtBackgroundSecondary.opacity(0.5)
        }
        return Color.clear
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Group {
            // File/folder specific actions
            if !node.isDirectory {
                Button("Open") {
                    fileTreeManager.openFile(node)
                }
            }

            Button("Reveal in Finder") {
                fileTreeManager.revealInFinder(node)
            }

            Divider()

            // Creation actions (for directories)
            if node.isDirectory {
                Menu("New") {
                    Button("File...") {
                        // This will be handled by the parent FileBrowserView
                    }

                    Button("Folder...") {
                        // This will be handled by the parent FileBrowserView
                    }
                }

                Divider()
            }
        }

        Group {
            // Edit actions
            Button("Rename...") {
                startRename()
            }

            Button("Duplicate") {
                performDuplicate()
            }

            Divider()

            Button("Delete...") {
                showDeleteConfirmation = true
            }

            Divider()

            Button("Copy Path") {
                fileTreeManager.copyPath(node)
            }

            if node.isDirectory {
                Divider()

                Button("Set as Root") {
                    fileTreeManager.changeRoot(to: node.url)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleTap() {
        fileTreeManager.select(node)

        if node.isDirectory {
            node.toggle(showHidden: fileTreeManager.showHidden)
        } else {
            // Double-click to open is better UX, but single click for selection
            // We could implement double-click detection if needed
        }
    }

    private func startRename() {
        isRenaming = true
        renamingText = node.name
    }

    private func cancelRename() {
        isRenaming = false
        renamingText = ""
    }

    private func performRename() {
        guard !renamingText.isEmpty, renamingText != node.name else {
            cancelRename()
            return
        }

        errorMessage = fileTreeManager.rename(node, to: renamingText)
        cancelRename()
    }

    private func performDelete() {
        errorMessage = fileTreeManager.delete(node)
    }

    private func performDuplicate() {
        errorMessage = fileTreeManager.duplicate(node)
    }
}

// MARK: - Preview

struct FileBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        FileBrowserView()
            .environmentObject(ShellSessionManager())
            .frame(width: 250, height: 600)
            .background(Color.rtBackgroundLight)
    }
}
