import Foundation
import AppKit
import Combine

/// Manages the file tree state and synchronization with terminal
class FileTreeManager: ObservableObject {
    @Published var rootNode: FileNode?
    @Published var currentDirectory: URL
    @Published var showHidden: Bool = false
    @Published var selectedNode: FileNode?

    // Callback for opening files in editor
    var onOpenFile: ((URL) -> Void)?

    // Callbacks for keyboard shortcut actions
    var onRenameRequested: ((FileNode) -> Void)?
    var onDeleteRequested: ((FileNode) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init(rootDirectory: URL? = nil) {
        // Default to user's home directory or project root
        if let root = rootDirectory {
            self.currentDirectory = root
        } else if let projectRoot = Self.detectProjectRoot() {
            self.currentDirectory = projectRoot
        } else {
            self.currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        loadRootNode()
        observeShowHidden()
    }

    /// Load the root node
    private func loadRootNode() {
        rootNode = FileNode(url: currentDirectory)
        rootNode?.isExpanded = true
        rootNode?.loadChildren(showHidden: showHidden)
    }

    /// Reload the file tree
    func reload() {
        loadRootNode()
    }

    /// Change root directory
    func changeRoot(to url: URL) {
        currentDirectory = url
        loadRootNode()
    }

    /// Toggle hidden files visibility
    func toggleHidden() {
        showHidden.toggle()
    }

    /// Select a node
    func select(_ node: FileNode) {
        selectedNode = node
    }

    /// Open file in internal editor or external app
    func openFile(_ node: FileNode) {
        // If callback is set and file is a text file, open in editor
        if let callback = onOpenFile, !node.isDirectory, isTextFile(node.url) {
            callback(node.url)
        } else {
            // Otherwise, open with system default
            NSWorkspace.shared.open(node.url)
        }
    }

    /// Check if file is a text file that can be edited
    private func isTextFile(_ url: URL) -> Bool {
        let textExtensions = [
            "swift", "txt", "md", "json", "xml", "yml", "yaml",
            "js", "ts", "jsx", "tsx", "py", "rb", "go", "rs",
            "c", "cpp", "h", "hpp", "java", "kt", "sh", "bash",
            "zsh", "fish", "css", "scss", "sass", "html", "vue",
            "sql", "toml", "conf", "ini", "env", "log", "gitignore"
        ]
        let ext = url.pathExtension.lowercased()
        return textExtensions.contains(ext)
    }

    /// Reveal in Finder
    func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    /// Copy path to clipboard
    func copyPath(_ node: FileNode) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(node.url.path, forType: .string)
    }

    // MARK: - File Operations

    /// Create a new file
    @discardableResult
    func createFile(in parent: FileNode?, name: String) -> String? {
        let parentURL: URL
        if let parent = parent {
            guard parent.isDirectory else {
                return "Parent is not a directory"
            }
            parentURL = parent.url
        } else {
            parentURL = currentDirectory
        }

        let fileURL = parentURL.appendingPathComponent(name)

        // Check if file already exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return "File already exists"
        }

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            // Reload the parent node
            reloadNode(parent)
            return nil
        } catch {
            return "Failed to create file: \(error.localizedDescription)"
        }
    }

    /// Create a new directory
    @discardableResult
    func createDirectory(in parent: FileNode?, name: String) -> String? {
        let parentURL: URL
        if let parent = parent {
            guard parent.isDirectory else {
                return "Parent is not a directory"
            }
            parentURL = parent.url
        } else {
            parentURL = currentDirectory
        }

        let dirURL = parentURL.appendingPathComponent(name)

        // Check if directory already exists
        if FileManager.default.fileExists(atPath: dirURL.path) {
            return "Directory already exists"
        }

        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false)
            // Reload the parent node
            reloadNode(parent)
            return nil
        } catch {
            return "Failed to create directory: \(error.localizedDescription)"
        }
    }

    /// Rename a file or directory
    @discardableResult
    func rename(_ node: FileNode, to newName: String) -> String? {
        let parentURL = node.url.deletingLastPathComponent()
        let newURL = parentURL.appendingPathComponent(newName)

        // Check if target already exists
        if FileManager.default.fileExists(atPath: newURL.path) {
            return "Target already exists"
        }

        do {
            try FileManager.default.moveItem(at: node.url, to: newURL)
            // Reload the parent node
            reloadParentNode(of: node)
            return nil
        } catch {
            return "Failed to rename: \(error.localizedDescription)"
        }
    }

    /// Delete a file or directory
    @discardableResult
    func delete(_ node: FileNode) -> String? {
        do {
            try FileManager.default.removeItem(at: node.url)

            // Clear selection if deleted node was selected
            if selectedNode?.id == node.id {
                selectedNode = nil
            }

            // Reload the parent node
            reloadParentNode(of: node)
            return nil
        } catch {
            return "Failed to delete: \(error.localizedDescription)"
        }
    }

    /// Duplicate a file or directory
    @discardableResult
    func duplicate(_ node: FileNode) -> String? {
        let parentURL = node.url.deletingLastPathComponent()
        let baseName = node.url.deletingPathExtension().lastPathComponent
        let ext = node.url.pathExtension

        // Find a unique name
        var counter = 1
        var newName: String
        var newURL: URL

        repeat {
            if ext.isEmpty {
                newName = "\(baseName) copy \(counter)"
            } else {
                newName = "\(baseName) copy \(counter).\(ext)"
            }
            newURL = parentURL.appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: newURL.path)

        do {
            try FileManager.default.copyItem(at: node.url, to: newURL)
            // Reload the parent node
            reloadParentNode(of: node)
            return nil
        } catch {
            return "Failed to duplicate: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Helpers

    /// Reload a specific node's children
    private func reloadNode(_ node: FileNode?) {
        if let node = node {
            node.children = nil
            if node.isExpanded {
                node.loadChildren(showHidden: showHidden)
            }
        } else {
            // Reload root
            reload()
        }
    }

    /// Reload the parent node of a given node
    private func reloadParentNode(of node: FileNode) {
        // For simplicity, just reload the entire tree
        // A more sophisticated approach would traverse the tree to find the parent
        reload()
    }

    // MARK: - Terminal Synchronization

    /// Synchronize with terminal's current directory
    func syncWithTerminal(workingDirectory: String) {
        let newURL = URL(fileURLWithPath: workingDirectory)

        // Only reload if directory actually changed
        if newURL != currentDirectory {
            changeRoot(to: newURL)
        }
    }

    // MARK: - Project Detection

    /// Detect project root by looking for common markers
    private static func detectProjectRoot() -> URL? {
        let currentPath = FileManager.default.currentDirectoryPath
        var url = URL(fileURLWithPath: currentPath)

        // Project markers to look for
        let markers = [
            ".git",
            "Package.swift",
            "Cargo.toml",
            "package.json",
            "go.mod",
            "Gemfile",
            "requirements.txt",
            ".xcodeproj",
            ".xcworkspace"
        ]

        // Walk up directory tree
        while url.path != "/" {
            for marker in markers {
                let markerURL = url.appendingPathComponent(marker)
                if FileManager.default.fileExists(atPath: markerURL.path) {
                    return url
                }
            }
            url = url.deletingLastPathComponent()
        }

        // Fall back to current directory
        return URL(fileURLWithPath: currentPath)
    }

    // MARK: - Private Helpers

    /// Observe showHidden changes and reload tree
    private func observeShowHidden() {
        $showHidden
            .dropFirst()
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    // MARK: - Keyboard Shortcut Notifications

    /// Notify that rename was requested (for keyboard shortcuts)
    func notifyRenameRequested(_ node: FileNode) {
        onRenameRequested?(node)
    }

    /// Notify that delete was requested (for keyboard shortcuts)
    func notifyDeleteRequested(_ node: FileNode) {
        onDeleteRequested?(node)
    }
}
