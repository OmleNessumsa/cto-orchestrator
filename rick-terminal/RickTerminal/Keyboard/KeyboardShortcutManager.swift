import SwiftUI
import Combine

/// Centralized manager for all keyboard shortcuts in Rick Terminal
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    @Published private(set) var shortcuts: [KeyboardShortcut] = []

    private init() {
        registerDefaultShortcuts()
    }

    // MARK: - Default Shortcuts Registration

    private func registerDefaultShortcuts() {
        shortcuts = [
            // MARK: Window Management
            KeyboardShortcut(
                id: "window.new",
                key: "n",
                modifiers: [.command],
                context: .global,
                title: "New Window",
                description: "Create a new terminal window",
                action: "newWindow"
            ),
            KeyboardShortcut(
                id: "window.newTab",
                key: "t",
                modifiers: [.command],
                context: .global,
                title: "New Tab",
                description: "Create a new terminal tab",
                action: "newTab"
            ),
            KeyboardShortcut(
                id: "window.closeTab",
                key: "w",
                modifiers: [.command],
                context: .global,
                title: "Close Tab",
                description: "Close current terminal tab",
                action: "closeTab"
            ),
            KeyboardShortcut(
                id: "window.previousTab",
                key: "[",
                modifiers: [.command, .shift],
                context: .global,
                title: "Previous Tab",
                description: "Switch to previous tab",
                action: "previousTab"
            ),
            KeyboardShortcut(
                id: "window.nextTab",
                key: "]",
                modifiers: [.command, .shift],
                context: .global,
                title: "Next Tab",
                description: "Switch to next tab",
                action: "nextTab"
            ),

            // MARK: View/Panel Toggles
            KeyboardShortcut(
                id: "view.toggleFileBrowser",
                key: "b",
                modifiers: [.command],
                context: .global,
                title: "Toggle File Browser",
                description: "Show or hide the file browser panel",
                action: "toggleFileBrowser"
            ),
            KeyboardShortcut(
                id: "view.toggleKanban",
                key: "k",
                modifiers: [.command, .shift],
                context: .global,
                title: "Toggle Kanban Board",
                description: "Show or hide the kanban board panel",
                action: "toggleKanban"
            ),
            KeyboardShortcut(
                id: "view.switchToTerminal",
                key: "1",
                modifiers: [.command],
                context: .global,
                title: "Switch to Terminal",
                description: "Switch to terminal view",
                action: "switchToTerminal"
            ),
            KeyboardShortcut(
                id: "view.switchToEditor",
                key: "2",
                modifiers: [.command],
                context: .global,
                title: "Switch to Editor",
                description: "Switch to editor view",
                action: "switchToEditor"
            ),

            // MARK: File Operations
            KeyboardShortcut(
                id: "file.openFolder",
                key: "o",
                modifiers: [.command, .shift],
                context: .global,
                title: "Open Folder",
                description: "Open a project folder",
                action: "openFolder"
            ),
            KeyboardShortcut(
                id: "file.save",
                key: "s",
                modifiers: [.command],
                context: .global,
                title: "Save",
                description: "Save the active file",
                action: "saveFile"
            ),
            KeyboardShortcut(
                id: "file.saveAll",
                key: "s",
                modifiers: [.command, .option],
                context: .global,
                title: "Save All",
                description: "Save all open files",
                action: "saveAll"
            ),
            KeyboardShortcut(
                id: "file.open",
                key: "o",
                modifiers: [.command],
                context: .global,
                title: "Open File",
                description: "Open a file in the editor",
                action: "openFile"
            ),
            KeyboardShortcut(
                id: "file.closeFile",
                key: "w",
                modifiers: [.command, .shift],
                context: .editor,
                title: "Close File",
                description: "Close the active file in editor",
                action: "closeFile"
            ),

            // MARK: Claude Integration
            KeyboardShortcut(
                id: "claude.toggleMode",
                key: "c",
                modifiers: [.command, .shift],
                context: .global,
                title: "Toggle Claude Mode",
                description: "Enable or disable Claude mode",
                action: "toggleClaudeMode"
            ),
            KeyboardShortcut(
                id: "claude.launch",
                key: "l",
                modifiers: [.command, .shift],
                context: .global,
                title: "Launch Claude CLI",
                description: "Launch the Claude CLI in terminal",
                action: "launchClaude"
            ),
            KeyboardShortcut(
                id: "claude.exit",
                key: "e",
                modifiers: [.command, .shift],
                context: .global,
                title: "Exit Claude CLI",
                description: "Exit the Claude CLI",
                action: "exitClaude"
            ),

            // MARK: Search & Navigation
            KeyboardShortcut(
                id: "search.find",
                key: "f",
                modifiers: [.command],
                context: .global,
                title: "Find",
                description: "Search in current view",
                action: "find"
            ),
            KeyboardShortcut(
                id: "search.findInFiles",
                key: "f",
                modifiers: [.command, .shift],
                context: .global,
                title: "Find in Files",
                description: "Search across all files",
                action: "findInFiles"
            ),

            // MARK: Terminal Operations
            KeyboardShortcut(
                id: "terminal.clear",
                key: "k",
                modifiers: [.command],
                context: .terminal,
                title: "Clear Terminal",
                description: "Clear terminal output",
                action: "clearTerminal"
            ),
            KeyboardShortcut(
                id: "terminal.interrupt",
                key: "c",
                modifiers: [.control],
                context: .terminal,
                title: "Interrupt",
                description: "Send interrupt signal (Ctrl+C)",
                action: "interruptProcess"
            ),

            // MARK: File Browser Operations
            KeyboardShortcut(
                id: "fileBrowser.newFile",
                key: "n",
                modifiers: [.command, .option],
                context: .fileBrowser,
                title: "New File",
                description: "Create a new file in current directory",
                action: "newFile"
            ),
            KeyboardShortcut(
                id: "fileBrowser.newFolder",
                key: "n",
                modifiers: [.command, .shift, .option],
                context: .fileBrowser,
                title: "New Folder",
                description: "Create a new folder in current directory",
                action: "newFolder"
            ),
            KeyboardShortcut(
                id: "fileBrowser.rename",
                key: "r",
                modifiers: [.command],
                context: .fileBrowser,
                title: "Rename",
                description: "Rename selected file or folder",
                action: "renameFile"
            ),
            KeyboardShortcut(
                id: "fileBrowser.duplicate",
                key: "d",
                modifiers: [.command],
                context: .fileBrowser,
                title: "Duplicate",
                description: "Duplicate selected file or folder",
                action: "duplicateFile"
            ),
            KeyboardShortcut(
                id: "fileBrowser.delete",
                key: .delete,
                modifiers: [],
                context: .fileBrowser,
                title: "Delete",
                description: "Delete selected file or folder",
                action: "deleteFile"
            ),
            KeyboardShortcut(
                id: "fileBrowser.revealInFinder",
                key: "r",
                modifiers: [.command, .shift],
                context: .fileBrowser,
                title: "Reveal in Finder",
                description: "Show selected file in Finder",
                action: "revealInFinder"
            ),
        ]
    }

    // MARK: - Shortcut Queries

    /// Get all shortcuts for a specific context
    func shortcuts(for context: KeyboardShortcutContext) -> [KeyboardShortcut] {
        return shortcuts.filter { $0.context == context || $0.context == .global }
    }

    /// Get shortcut by ID
    func shortcut(withId id: String) -> KeyboardShortcut? {
        return shortcuts.first { $0.id == id }
    }

    /// Get shortcuts by action
    func shortcuts(forAction action: String) -> [KeyboardShortcut] {
        return shortcuts.filter { $0.action == action }
    }

    /// Get all shortcuts that have conflicts
    func conflictingShortcuts() -> [KeyboardShortcut] {
        return shortcuts.filter { $0.conflictsWithSystem }
    }

    // MARK: - Shortcut Management

    /// Register a custom shortcut
    func register(_ shortcut: KeyboardShortcut) {
        // Remove existing shortcut with same ID
        shortcuts.removeAll { $0.id == shortcut.id }
        shortcuts.append(shortcut)
    }

    /// Unregister a shortcut by ID
    func unregister(id: String) {
        shortcuts.removeAll { $0.id == id }
    }

    /// Update an existing shortcut
    func update(_ shortcut: KeyboardShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        }
    }

    // MARK: - Persistence (for future use)

    /// Save shortcuts to user defaults (future feature)
    func saveToUserDefaults() {
        // TODO: Implement when making shortcuts configurable
        // let encoder = JSONEncoder()
        // if let data = try? encoder.encode(shortcuts) {
        //     UserDefaults.standard.set(data, forKey: "customKeyboardShortcuts")
        // }
    }

    /// Load shortcuts from user defaults (future feature)
    func loadFromUserDefaults() {
        // TODO: Implement when making shortcuts configurable
        // guard let data = UserDefaults.standard.data(forKey: "customKeyboardShortcuts") else { return }
        // let decoder = JSONDecoder()
        // if let loaded = try? decoder.decode([KeyboardShortcut].self, from: data) {
        //     shortcuts = loaded
        // }
    }
}

// MARK: - Notification Names for Shortcuts

extension Notification.Name {
    // Window Management
    static let newWindow = Notification.Name("newWindow")
    static let newTab = Notification.Name("newTab")
    static let closeTab = Notification.Name("closeTab")
    static let previousTab = Notification.Name("previousTab")
    static let nextTab = Notification.Name("nextTab")

    // View/Panel Toggles
    static let toggleFileBrowser = Notification.Name("toggleFileBrowser")
    static let toggleKanban = Notification.Name("toggleKanban")
    static let switchToTerminal = Notification.Name("switchToTerminal")
    static let switchToEditor = Notification.Name("switchToEditor")

    // File Operations (saveFile already exists)
    static let openFolder = Notification.Name("openFolder")
    static let saveAll = Notification.Name("saveAll")
    static let openFile = Notification.Name("openFile")
    static let closeFile = Notification.Name("closeFile")

    // Claude Integration (toggleClaudeMode, launchClaude, exitClaude already exist)

    // Search & Navigation
    static let find = Notification.Name("find")
    static let findInFiles = Notification.Name("findInFiles")

    // Terminal Operations
    static let clearTerminal = Notification.Name("clearTerminal")
    static let interruptProcess = Notification.Name("interruptProcess")

    // Help
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")

    // File Browser Operations
    static let newFile = Notification.Name("newFile")
    static let newFolder = Notification.Name("newFolder")
    static let renameFile = Notification.Name("renameFile")
    static let duplicateFile = Notification.Name("duplicateFile")
    static let deleteFile = Notification.Name("deleteFile")
    static let revealInFinder = Notification.Name("revealInFinder")

    // Git Operations
    static let gitStatusRefreshNeeded = Notification.Name("gitStatusRefreshNeeded")
}
