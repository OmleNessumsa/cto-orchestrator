import SwiftUI

/// View showing all available keyboard shortcuts grouped by category
struct KeyboardShortcutsView: View {
    @ObservedObject var manager = KeyboardShortcutManager.shared
    @Environment(\.dismiss) private var dismiss

    // Group shortcuts by category
    private var groupedShortcuts: [(String, [KeyboardShortcut])] {
        let groups: [(String, [String])] = [
            ("Window Management", ["window.new", "window.newTab", "window.closeTab", "window.previousTab", "window.nextTab"]),
            ("View & Panels", ["view.toggleFileBrowser", "view.toggleKanban", "view.switchToTerminal", "view.switchToEditor"]),
            ("File Operations", ["file.save", "file.saveAll", "file.open", "file.closeFile"]),
            ("Claude Integration", ["claude.toggleMode", "claude.launch", "claude.exit"]),
            ("Search & Navigation", ["search.find", "search.findInFiles"]),
            ("Terminal Operations", ["terminal.clear", "terminal.interrupt"]),
        ]

        return groups.compactMap { (category, ids) in
            let shortcuts = ids.compactMap { manager.shortcut(withId: $0) }
            return shortcuts.isEmpty ? nil : (category, shortcuts)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.rtTextPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.rtTextSecondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.rtBackgroundLight)

            Divider()
                .background(Color.rtBorderSubtle)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(groupedShortcuts, id: \.0) { category, shortcuts in
                        VStack(alignment: .leading, spacing: 12) {
                            // Category header
                            Text(category)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtAccentGreen)
                                .padding(.bottom, 4)

                            // Shortcuts in this category
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(shortcuts) { shortcut in
                                    ShortcutRow(shortcut: shortcut)
                                }
                            }
                        }
                    }

                    // System shortcut warnings
                    if !manager.conflictingShortcuts().isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠ System Conflicts")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtAccentOrange)

                            Text("The following shortcuts may conflict with macOS system shortcuts:")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.rtTextSecondary)

                            ForEach(manager.conflictingShortcuts()) { shortcut in
                                ShortcutRow(shortcut: shortcut, showWarning: true)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .background(Color.rtBackgroundDark)
        }
        .frame(width: 600, height: 500)
        .background(Color.rtBackgroundDark)
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let shortcut: KeyboardShortcut
    var showWarning: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Title
            Text(shortcut.title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.rtTextPrimary)
                .frame(width: 180, alignment: .leading)

            Spacer()

            // Description
            Text(shortcut.description)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.rtTextSecondary)
                .lineLimit(1)
                .frame(maxWidth: 250, alignment: .leading)

            Spacer()

            // Shortcut display
            HStack(spacing: 4) {
                if showWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.rtAccentOrange)
                        .font(.system(size: 10))
                }

                Text(shortcut.displayString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.rtTextPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.rtBackgroundLight)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(showWarning ? Color.rtAccentOrange : Color.rtBorderSubtle, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.rtBackgroundLight.opacity(0.3))
        )
    }
}

// MARK: - Preview

struct KeyboardShortcutsView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardShortcutsView()
    }
}
