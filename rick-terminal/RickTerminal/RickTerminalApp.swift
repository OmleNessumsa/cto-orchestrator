import SwiftUI

@main
struct RickTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Window commands for new window and new tab
            CommandGroup(after: .newItem) {
                ShortcutButton(shortcutId: "window.new") {
                    NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
                }

                ShortcutButton(shortcutId: "window.newTab") {
                    if let window = NSApp.keyWindow {
                        window.addTabbedWindow(NSWindow(), ordered: .above)
                    }
                }

                ShortcutButton(shortcutId: "window.closeTab") {
                    NSApp.keyWindow?.performClose(nil)
                }

                Divider()

                Button("Merge All Windows") {
                    NSApp.windows.first?.mergeAllWindows(nil)
                }

                ShortcutButton(shortcutId: "window.previousTab") {
                    NSApp.keyWindow?.selectPreviousTab(nil)
                }

                ShortcutButton(shortcutId: "window.nextTab") {
                    NSApp.keyWindow?.selectNextTab(nil)
                }
            }

            // View menu for panel toggles
            CommandMenu("View") {
                ShortcutButton(shortcutId: "view.toggleFileBrowser") {
                    NotificationCenter.default.post(name: .toggleFileBrowser, object: nil)
                }

                ShortcutButton(shortcutId: "view.toggleKanban") {
                    NotificationCenter.default.post(name: .toggleKanban, object: nil)
                }

                Divider()

                ShortcutButton(shortcutId: "view.switchToTerminal") {
                    NotificationCenter.default.post(name: .switchToTerminal, object: nil)
                }

                ShortcutButton(shortcutId: "view.switchToEditor") {
                    NotificationCenter.default.post(name: .switchToEditor, object: nil)
                }
            }

            // File menu
            CommandGroup(replacing: .saveItem) {
                ShortcutButton(shortcutId: "file.openFolder") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }

                ShortcutButton(shortcutId: "file.open") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }

                Divider()

                ShortcutButton(shortcutId: "file.save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }

                ShortcutButton(shortcutId: "file.saveAll") {
                    NotificationCenter.default.post(name: .saveAll, object: nil)
                }

                Divider()

                ShortcutButton(shortcutId: "file.closeFile") {
                    NotificationCenter.default.post(name: .closeFile, object: nil)
                }
            }

            // Claude menu
            CommandMenu("Claude") {
                ShortcutButton(shortcutId: "claude.toggleMode") {
                    NotificationCenter.default.post(name: .toggleClaudeMode, object: nil)
                }

                ShortcutButton(shortcutId: "claude.launch") {
                    NotificationCenter.default.post(name: .launchClaude, object: nil)
                }

                ShortcutButton(shortcutId: "claude.exit") {
                    NotificationCenter.default.post(name: .exitClaude, object: nil)
                }
            }

            // Search menu
            CommandMenu("Search") {
                ShortcutButton(shortcutId: "search.find") {
                    NotificationCenter.default.post(name: .find, object: nil)
                }

                ShortcutButton(shortcutId: "search.findInFiles") {
                    NotificationCenter.default.post(name: .findInFiles, object: nil)
                }
            }

            // Terminal menu
            CommandMenu("Terminal") {
                ShortcutButton(shortcutId: "terminal.clear") {
                    NotificationCenter.default.post(name: .clearTerminal, object: nil)
                }

                ShortcutButton(shortcutId: "terminal.interrupt") {
                    NotificationCenter.default.post(name: .interruptProcess, object: nil)
                }

                Divider()

                Button("Session History...") {
                    NotificationCenter.default.post(name: .showSessionHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }

            // File Browser menu
            CommandMenu("File Browser") {
                ShortcutButton(shortcutId: "fileBrowser.newFile") {
                    NotificationCenter.default.post(name: .newFile, object: nil)
                }

                ShortcutButton(shortcutId: "fileBrowser.newFolder") {
                    NotificationCenter.default.post(name: .newFolder, object: nil)
                }

                Divider()

                ShortcutButton(shortcutId: "fileBrowser.rename") {
                    NotificationCenter.default.post(name: .renameFile, object: nil)
                }

                ShortcutButton(shortcutId: "fileBrowser.duplicate") {
                    NotificationCenter.default.post(name: .duplicateFile, object: nil)
                }

                ShortcutButton(shortcutId: "fileBrowser.delete") {
                    NotificationCenter.default.post(name: .deleteFile, object: nil)
                }

                Divider()

                ShortcutButton(shortcutId: "fileBrowser.revealInFinder") {
                    NotificationCenter.default.post(name: .revealInFinder, object: nil)
                }
            }

            // Help menu
            CommandGroup(after: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
        .defaultAppStorage(UserDefaults(suiteName: "com.rickportal.rickterminal") ?? .standard)

        // Settings window
        Settings {
            PreferencesView()
        }
    }
}

// MARK: - ShortcutButton Helper

/// Helper view that creates a button with a keyboard shortcut from the manager
struct ShortcutButton: View {
    let shortcutId: String
    let action: () -> Void

    @StateObject private var shortcutManager = KeyboardShortcutManager.shared

    var body: some View {
        if let shortcut = shortcutManager.shortcut(withId: shortcutId) {
            Button(shortcut.title) {
                action()
            }
            .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        } else {
            Button("Unknown Shortcut") {
                action()
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleClaudeMode = Notification.Name("toggleClaudeMode")
    static let launchClaude = Notification.Name("launchClaude")
    static let exitClaude = Notification.Name("exitClaude")
    static let saveFile = Notification.Name("saveFile")
    static let showSessionHistory = Notification.Name("showSessionHistory")
}
