import SwiftUI

// MARK: - RTIcon Usage Examples
//
// This file demonstrates how to use the RTIcon system throughout the application.
// RTIcon provides a centralized, type-safe way to use SF Symbols icons.
//
// DO NOT include this file in production builds - it's for documentation only.

#if DEBUG

// MARK: - Example 1: Basic Usage

struct IconExampleBasic: View {
    var body: some View {
        VStack(spacing: 20) {
            // Method 1: Using the .image property
            RTIcon.terminal.image
                .foregroundColor(.rtAccentGreen)

            // Method 2: Using the helper with size
            RTIcon.folder.image(size: 24)

            // Method 3: Using the helper with size and color
            RTIcon.add.image(size: 16, color: .rtAccentPurple)

            // Method 4: Manual Image creation (if you need more control)
            Image(systemName: RTIcon.search.symbolName)
                .font(.system(size: 20))
                .foregroundColor(.rtTextPrimary)
        }
    }
}

// MARK: - Example 2: Button Icons

struct IconExampleButtons: View {
    var body: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: {}) {
                RTIcon.close.image
                    .foregroundColor(.rtTextSecondary)
            }
            .buttonStyle(.plain)

            // Add button
            Button(action: {}) {
                RTIcon.add.image
                    .foregroundColor(.rtAccentGreen)
            }
            .buttonStyle(.plain)

            // Refresh button
            Button(action: {}) {
                RTIcon.refresh.image
                    .foregroundColor(.rtAccentPurple)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Example 3: Conditional Icons

struct IconExampleConditional: View {
    @State private var isVisible = true
    @State private var isSidebarCollapsed = false

    var body: some View {
        VStack(spacing: 20) {
            // Visibility toggle
            Button(action: { isVisible.toggle() }) {
                (isVisible ? RTIcon.reviewFilled : RTIcon.hidden).image
                    .foregroundColor(.rtAccentGreen)
            }

            // Sidebar toggle
            Button(action: { isSidebarCollapsed.toggle() }) {
                (isSidebarCollapsed ? RTIcon.sidebarLeft : RTIcon.sidebarLeftFilled).image
                    .foregroundColor(.rtAccentGreen)
            }

            // Folder expansion
            let isExpanded = true
            (isExpanded ? RTIcon.folderMinusFilled : RTIcon.folderFilled).image
                .foregroundColor(Color(hex: "7B78AA"))
        }
    }
}

// MARK: - Example 4: List/Row Icons

struct IconExampleList: View {
    var body: some View {
        List {
            // Agent roles
            HStack {
                RTIcon.architect.image
                    .foregroundColor(.rtAccentPurple)
                Text("Architect Morty")
            }

            HStack {
                RTIcon.frontend.image
                    .foregroundColor(Color(hex: "FF9800"))
                Text("Frontend Morty")
            }

            HStack {
                RTIcon.backend.image
                    .foregroundColor(Color(hex: "2196F3"))
                Text("Backend Morty")
            }

            // Tool actions
            HStack {
                RTIcon.bash.image
                    .foregroundColor(.rtAccentGreen)
                Text("Running bash command")
            }

            HStack {
                RTIcon.edit.image
                    .foregroundColor(.rtAccentPurple)
                Text("Editing file")
            }
        }
    }
}

// MARK: - Example 5: Status Indicators

struct IconExampleStatus: View {
    var body: some View {
        HStack(spacing: 30) {
            // Success
            VStack {
                RTIcon.checkCircleFilled.image
                    .foregroundColor(Color(hex: "4CAF50"))
                Text("Success")
                    .font(.caption)
            }

            // Warning
            VStack {
                RTIcon.warningFilled.image
                    .foregroundColor(Color(hex: "FF9800"))
                Text("Warning")
                    .font(.caption)
            }

            // Error
            VStack {
                RTIcon.errorFilled.image
                    .foregroundColor(Color(hex: "F44336"))
                Text("Error")
                    .font(.caption)
            }

            // Info
            VStack {
                RTIcon.infoFilled.image
                    .foregroundColor(.rtAccentPurple)
                Text("Info")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Example 6: Priority Indicators

struct IconExamplePriority: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RTIcon.priorityLow.image
                    .foregroundColor(.rtTextSecondary)
                Text("Low Priority")
            }

            HStack {
                RTIcon.priorityMedium.image
                    .foregroundColor(.rtAccentBlue)
                Text("Medium Priority")
            }

            HStack {
                RTIcon.priorityHigh.image
                    .foregroundColor(.rtAccentPurple)
                Text("High Priority")
            }

            HStack {
                RTIcon.priorityCritical.image
                    .foregroundColor(.red)
                Text("Critical Priority")
            }
        }
    }
}

// MARK: - Example 7: Card Sources

struct IconExampleSources: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RTIcon.manual.image
                Text("Manual")
            }

            HStack {
                RTIcon.ai.image
                Text("Claude Generated")
            }

            HStack {
                RTIcon.ticket.image
                Text("Ticket Reference")
            }

            HStack {
                RTIcon.subAgent.image
                Text("Sub-Agent Task")
            }
        }
    }
}

// MARK: - Example 8: Tab/Mode Icons

struct IconExampleTabs: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                Button(action: { selectedTab = 0 }) {
                    HStack(spacing: 4) {
                        RTIcon.terminal.image
                            .font(.system(size: 11))
                        Text("Terminal")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == 0 ? Color.rtBackgroundDark : Color.clear)
                    .foregroundColor(selectedTab == 0 ? .rtTextPrimary : .rtTextSecondary)
                }
                .buttonStyle(.plain)

                Button(action: { selectedTab = 1 }) {
                    HStack(spacing: 4) {
                        RTIcon.document.image
                            .font(.system(size: 11))
                        Text("Editor")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == 1 ? Color.rtBackgroundDark : Color.clear)
                    .foregroundColor(selectedTab == 1 ? .rtTextPrimary : .rtTextSecondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .background(Color.rtBackgroundLight)

            Spacer()
        }
    }
}

// MARK: - Example 9: Agent Status

struct IconExampleAgentStatus: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RTIcon.ai.image
                    .foregroundColor(Color(hex: "00BCD4"))
                Text("Spawning")
            }

            HStack {
                RTIcon.working.image
                    .foregroundColor(.rtAccentGreen)
                Text("Working")
            }

            HStack {
                RTIcon.idle.image
                    .foregroundColor(.rtMuted)
                Text("Idle")
            }

            HStack {
                RTIcon.checkCircleFilled.image
                    .foregroundColor(Color(hex: "4CAF50"))
                Text("Done")
            }
        }
    }
}

// MARK: - Example 10: File Browser Icons

struct IconExampleFileBrowser: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Toolbar buttons
            HStack(spacing: 12) {
                RTIcon.reviewFilled.image
                    .foregroundColor(.rtAccentGreen)

                RTIcon.refresh.image
                    .foregroundColor(.rtAccentGreen)

                RTIcon.folderCreate.image
                    .foregroundColor(.rtAccentGreen)
            }

            Divider()

            // File tree items
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    RTIcon.chevronDown.image
                    RTIcon.folderFilled.image
                        .foregroundColor(Color(hex: "7B78AA"))
                    Text("src/")
                }

                HStack {
                    Spacer().frame(width: 16)
                    RTIcon.swift.image
                        .foregroundColor(Color(hex: "F05138"))
                    Text("main.swift")
                }

                HStack {
                    Spacer().frame(width: 16)
                    RTIcon.document.image
                        .foregroundColor(.rtTextSecondary)
                    Text("config.json")
                }
            }
        }
    }
}

// MARK: - Example 11: Replacing systemName Strings

struct IconExampleMigration: View {
    var body: some View {
        VStack(spacing: 20) {
            // OLD WAY (string-based, error-prone)
            Image(systemName: "terminal")
                .foregroundColor(.rtAccentGreen)

            // NEW WAY (type-safe, autocomplete-friendly)
            RTIcon.terminal.image
                .foregroundColor(.rtAccentGreen)

            // Another example
            // OLD:
            Image(systemName: "sidebar.left.fill")

            // NEW:
            RTIcon.sidebarLeftFilled.image
        }
    }
}

// MARK: - Example 12: Common Patterns

struct IconExamplePatterns: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pattern 1: Icon + Text Label
            Label {
                Text("Terminal")
            } icon: {
                RTIcon.terminal.image
            }

            // Pattern 2: Icon Button with Help Text
            Button(action: {}) {
                RTIcon.settings.image
                    .foregroundColor(.rtAccentGreen)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Open Settings")

            // Pattern 3: Status Icon with Badge
            ZStack(alignment: .topTrailing) {
                RTIcon.document.image
                    .font(.system(size: 24))

                // Unsaved indicator
                Circle()
                    .fill(Color.rtAccentGreen)
                    .frame(width: 8, height: 8)
                    .offset(x: 4, y: -4)
            }

            // Pattern 4: Icon with circular background
            ZStack {
                Circle()
                    .fill(Color.rtAccentPurple.opacity(0.2))
                    .frame(width: 32, height: 32)

                RTIcon.ai.image
                    .foregroundColor(.rtAccentPurple)
            }
        }
    }
}

#endif

// MARK: - Production Usage Notes
//
// In production code, simply use RTIcon directly:
//
// ```swift
// Button(action: { /* action */ }) {
//     RTIcon.add.image
//         .foregroundColor(.rtAccentGreen)
// }
// ```
//
// Benefits:
// - Type-safe (autocomplete helps you find the right icon)
// - Centralized (easy to change icons globally)
// - Consistent naming (no more guessing systemName strings)
// - No emojis (professional SF Symbols only)
// - Easy to refactor (compiler catches all usages)
