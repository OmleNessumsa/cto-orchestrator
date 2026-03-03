import SwiftUI

/// Defines where a keyboard shortcut should be active
enum KeyboardShortcutContext: String, Codable {
    case global         // Active everywhere in the app
    case terminal       // Active only in terminal view
    case editor         // Active only in editor view
    case fileBrowser    // Active only in file browser
    case kanban         // Active only in kanban board
}

/// Represents a keyboard shortcut with its metadata
struct KeyboardShortcut: Identifiable, Codable {
    let id: String
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let context: KeyboardShortcutContext
    let title: String
    let description: String
    let action: String  // Notification name to post

    /// Check if this shortcut conflicts with macOS system shortcuts
    var conflictsWithSystem: Bool {
        // Common macOS shortcuts that we should avoid (as character strings)
        let systemShortcuts: [(String, EventModifiers)] = [
            // Cmd+Q (Quit)
            ("q", [.command]),
            // Cmd+H (Hide)
            ("h", [.command]),
            // Cmd+M (Minimize)
            ("m", [.command]),
            // Cmd+, (Preferences)
            (",", [.command]),
            // Cmd+Space (Spotlight)
            (" ", [.command]),
            // Cmd+Tab (App Switcher)
            ("\t", [.command]),
        ]

        let keyChar = String(key.character)
        return systemShortcuts.contains { shortcut in
            shortcut.0 == keyChar && shortcut.1 == modifiers
        }
    }

    /// User-friendly display string for the shortcut
    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }

        parts.append(keyDisplayString)

        return parts.joined()
    }

    private var keyDisplayString: String {
        // Map common keys to display strings
        let keyString = String(describing: key.character)
        switch keyString {
        case " ": return "Space"
        case "\t": return "Tab"
        case "\r": return "Return"
        case "\u{1B}": return "Esc"
        default: return keyString.uppercased()
        }
    }
}

// MARK: - Codable Support for SwiftUI Types

extension KeyboardShortcut {
    enum CodingKeys: String, CodingKey {
        case id, keyChar, modifierFlags, context, title, description, action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        let keyChar = try container.decode(String.self, forKey: .keyChar)
        key = KeyEquivalent(Character(keyChar))

        let modifierFlags = try container.decode([String].self, forKey: .modifierFlags)
        var mods: EventModifiers = []
        if modifierFlags.contains("command") { mods.insert(.command) }
        if modifierFlags.contains("shift") { mods.insert(.shift) }
        if modifierFlags.contains("option") { mods.insert(.option) }
        if modifierFlags.contains("control") { mods.insert(.control) }
        modifiers = mods

        context = try container.decode(KeyboardShortcutContext.self, forKey: .context)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        action = try container.decode(String.self, forKey: .action)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(String(key.character), forKey: .keyChar)

        var modifierFlags: [String] = []
        if modifiers.contains(.command) { modifierFlags.append("command") }
        if modifiers.contains(.shift) { modifierFlags.append("shift") }
        if modifiers.contains(.option) { modifierFlags.append("option") }
        if modifiers.contains(.control) { modifierFlags.append("control") }
        try container.encode(modifierFlags, forKey: .modifierFlags)

        try container.encode(context, forKey: .context)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(action, forKey: .action)
    }
}
