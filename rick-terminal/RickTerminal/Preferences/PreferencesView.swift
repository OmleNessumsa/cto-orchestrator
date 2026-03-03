import SwiftUI

/// Main preferences window with sidebar navigation
struct PreferencesView: View {
    @State private var selectedSection: PreferenceSection = .general

    enum PreferenceSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case terminal = "Terminal"
        case claude = "Claude Integration"
        case keyboard = "Keyboard Shortcuts"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .terminal: return "terminal"
            case .claude: return "brain"
            case .keyboard: return "keyboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(PreferenceSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label {
                        Text(section.rawValue)
                            .foregroundColor(Color.rtText)
                    } icon: {
                        Image(systemName: section.icon)
                            .foregroundColor(Color.rtAccentGreen)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .listStyle(.sidebar)
            .background(Color.rtBackgroundLight)
        } detail: {
            // Detail view based on selection
            Group {
                switch selectedSection {
                case .general:
                    GeneralPreferencesView()
                case .appearance:
                    AppearancePreferencesView()
                case .terminal:
                    TerminalPreferencesView()
                case .claude:
                    ClaudeIntegrationPreferencesView()
                case .keyboard:
                    KeyboardShortcutsPreferencesView()
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .background(Color.rtBackgroundDark)
        }
        .frame(width: 850, height: 600)
    }
}

// MARK: - Preview

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
