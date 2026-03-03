import SwiftUI

/// Keyboard shortcuts preferences - view and customize all keyboard shortcuts
struct KeyboardShortcutsPreferencesView: View {
    @ObservedObject var shortcutManager = KeyboardShortcutManager.shared
    @State private var searchText: String = ""
    @State private var selectedContext: KeyboardShortcutContext? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.rtText)

                Text("View all available keyboard shortcuts organized by category")
                    .font(.caption)
                    .foregroundColor(Color.rtTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.rtBackgroundDark)

            Divider()
                .background(Color.rtBorderSubtle)

            // Search and filter
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.rtTextSecondary)

                    TextField("Search shortcuts...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.rtBackgroundLight)
                .cornerRadius(6)

                Picker("Filter", selection: $selectedContext) {
                    Text("All").tag(nil as KeyboardShortcutContext?)
                    ForEach([
                        KeyboardShortcutContext.global,
                        .terminal,
                        .editor,
                        .fileBrowser,
                        .kanban
                    ], id: \.self) { context in
                        Text(context.rawValue.capitalized).tag(context as KeyboardShortcutContext?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()
                .background(Color.rtBorderSubtle)

            // Shortcuts list
            ScrollView {
                VStack(spacing: 0) {
                    // Group by category
                    ForEach(groupedShortcuts, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            // Category header
                            Text(group.category)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.rtAccentGreen)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.rtBackgroundLight.opacity(0.5))

                            // Shortcuts in category
                            ForEach(group.shortcuts) { shortcut in
                                shortcutRow(shortcut)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.rtBackgroundDark)
    }

    // MARK: - Shortcut Row

    private func shortcutRow(_ shortcut: KeyboardShortcut) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.title)
                    .font(.subheadline)
                    .foregroundColor(Color.rtText)

                Text(shortcut.description)
                    .font(.caption)
                    .foregroundColor(Color.rtTextSecondary)
            }

            Spacer()

            // Context badge
            if shortcut.context != .global {
                Text(shortcut.context.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(Color.rtTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.rtMuted.opacity(0.3))
                    .cornerRadius(4)
            }

            // Shortcut display
            Text(shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color.rtAccentPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.rtBackgroundLight)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.rtBorderSubtle, lineWidth: 1)
                )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.rtBackgroundDark)
        .overlay(
            Rectangle()
                .fill(Color.rtBorderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Computed Properties

    private var filteredShortcuts: [KeyboardShortcut] {
        var shortcuts = shortcutManager.shortcuts

        // Filter by context
        if let context = selectedContext {
            shortcuts = shortcuts.filter { $0.context == context }
        }

        // Filter by search text
        if !searchText.isEmpty {
            shortcuts = shortcuts.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.displayString.localizedCaseInsensitiveContains(searchText)
            }
        }

        return shortcuts
    }

    private var groupedShortcuts: [ShortcutGroup] {
        let shortcuts = filteredShortcuts

        // Group by category (inferred from ID prefix)
        var groups: [String: [KeyboardShortcut]] = [:]

        for shortcut in shortcuts {
            let category = categoryName(for: shortcut)
            groups[category, default: []].append(shortcut)
        }

        // Convert to array and sort
        return groups.map { ShortcutGroup(category: $0.key, shortcuts: $0.value) }
            .sorted { $0.category < $1.category }
    }

    private func categoryName(for shortcut: KeyboardShortcut) -> String {
        let prefix = shortcut.id.split(separator: ".").first ?? ""

        switch prefix {
        case "window":
            return "Window Management"
        case "view":
            return "View & Panels"
        case "file":
            return "File Operations"
        case "claude":
            return "Claude Integration"
        case "search":
            return "Search & Navigation"
        case "terminal":
            return "Terminal"
        case "fileBrowser":
            return "File Browser"
        default:
            return "Other"
        }
    }

    struct ShortcutGroup {
        let category: String
        let shortcuts: [KeyboardShortcut]
    }
}

// MARK: - Preview

struct KeyboardShortcutsPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardShortcutsPreferencesView()
            .frame(width: 700, height: 600)
    }
}
