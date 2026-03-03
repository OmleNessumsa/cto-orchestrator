import Foundation
import Combine

/// Represents a persisted editor tab
struct PersistedEditorTab: Codable {
    let filePath: String
    let isActive: Bool
}

/// Manages open editor files and active file state
class EditorManager: ObservableObject {
    @Published var openFiles: [EditorFile] = []
    @Published var activeFileId: UUID?

    private let persistenceManager = SessionPersistenceManager.shared
    private let editorStateKey = "editorOpenTabs"

    var activeFile: EditorFile? {
        guard let id = activeFileId else { return nil }
        return openFiles.first { $0.id == id }
    }

    var hasUnsavedChanges: Bool {
        openFiles.contains { $0.hasUnsavedChanges }
    }

    init() {
        restoreOpenTabs()
    }

    // MARK: - File Management

    /// Open a file in the editor
    func openFile(url: URL) {
        // Check if file is already open
        if let existingFile = openFiles.first(where: { $0.url == url }) {
            activeFileId = existingFile.id
            return
        }

        // Load file
        do {
            let file = try EditorFile.load(from: url)
            openFiles.append(file)
            activeFileId = file.id
            saveOpenTabs()
        } catch {
            // Error already handled by EditorFile.load
            // Just log it here for debugging
            #if DEBUG
            print("Failed to open file: \(url.path)")
            #endif
        }
    }

    /// Close a file
    /// - Returns: true if closed, false if user cancelled due to unsaved changes
    @discardableResult
    func closeFile(_ file: EditorFile, force: Bool = false) -> Bool {
        // Check for unsaved changes
        if file.hasUnsavedChanges && !force {
            // Caller should show warning dialog
            return false
        }

        // Remove file
        openFiles.removeAll { $0.id == file.id }

        // Update active file if needed
        if activeFileId == file.id {
            activeFileId = openFiles.first?.id
        }

        saveOpenTabs()
        return true
    }

    /// Save the active file
    func saveActiveFile() {
        guard let file = activeFile else { return }

        do {
            try file.save()
        } catch {
            // Error already handled by EditorFile.save
        }
    }

    /// Save a specific file
    func saveFile(_ file: EditorFile) {
        do {
            try file.save()
        } catch {
            // Error already handled by EditorFile.save
        }
    }

    /// Save all open files
    func saveAll() {
        for file in openFiles {
            if file.hasUnsavedChanges {
                do {
                    try file.save()
                } catch {
                    // Error already handled by EditorFile.save
                    // Continue saving other files
                }
            }
        }
    }

    /// Set active file by ID
    func setActiveFile(_ id: UUID) {
        if openFiles.contains(where: { $0.id == id }) {
            activeFileId = id
            saveOpenTabs()
        }
    }

    /// Get file by ID
    func getFile(_ id: UUID) -> EditorFile? {
        return openFiles.first { $0.id == id }
    }

    /// Close all files
    func closeAll(force: Bool = false) -> Bool {
        if !force && hasUnsavedChanges {
            return false
        }

        openFiles.removeAll()
        activeFileId = nil
        saveOpenTabs()
        return true
    }

    // MARK: - Tab Reordering

    /// Move a tab from one index to another
    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < openFiles.count,
              destinationIndex >= 0, destinationIndex < openFiles.count else {
            return
        }

        let file = openFiles.remove(at: sourceIndex)
        openFiles.insert(file, at: destinationIndex)
        saveOpenTabs()
    }

    /// Reorder tabs based on an array of file IDs
    func reorderTabs(_ orderedIds: [UUID]) {
        guard orderedIds.count == openFiles.count else { return }

        var reorderedFiles: [EditorFile] = []
        for id in orderedIds {
            if let file = openFiles.first(where: { $0.id == id }) {
                reorderedFiles.append(file)
            }
        }

        if reorderedFiles.count == openFiles.count {
            openFiles = reorderedFiles
            saveOpenTabs()
        }
    }

    // MARK: - Persistence

    /// Save currently open tabs to UserDefaults
    func saveOpenTabs() {
        let tabs = openFiles.map { file in
            PersistedEditorTab(
                filePath: file.url.path,
                isActive: file.id == activeFileId
            )
        }

        if let data = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(data, forKey: editorStateKey)
        }
    }

    /// Restore previously open tabs from UserDefaults
    private func restoreOpenTabs() {
        guard let data = UserDefaults.standard.data(forKey: editorStateKey),
              let tabs = try? JSONDecoder().decode([PersistedEditorTab].self, from: data) else {
            return
        }

        for tab in tabs {
            let url = URL(fileURLWithPath: tab.filePath)

            // Only restore if file still exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            do {
                let file = try EditorFile.load(from: url)
                openFiles.append(file)

                if tab.isActive {
                    activeFileId = file.id
                }
            } catch {
                // Skip files that can't be loaded
                #if DEBUG
                print("Failed to restore file: \(url.path)")
                #endif
            }
        }
    }

    /// Clear persisted tab state
    func clearPersistedTabs() {
        UserDefaults.standard.removeObject(forKey: editorStateKey)
    }
}
