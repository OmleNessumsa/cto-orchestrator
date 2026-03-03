import SwiftUI

/// General preferences - app behavior and startup settings
struct GeneralPreferencesView: View {
    @AppStorage("startupBehavior") private var startupBehavior: StartupBehavior = .newWindow
    @AppStorage("restoreSessionsOnStartup") private var restoreSessions: Bool = true
    @AppStorage("confirmBeforeQuitting") private var confirmBeforeQuitting: Bool = true
    @AppStorage("showWelcomeOnFirstLaunch") private var showWelcome: Bool = true
    @AppStorage("defaultWorkingDirectory") private var defaultWorkingDirectory: String = ""
    @State private var directoryInput: String = ""

    enum StartupBehavior: String, CaseIterable, Identifiable {
        case newWindow = "New Window"
        case restoreSession = "Restore Last Session"
        case nothing = "Nothing"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .newWindow:
                return "Always open a new terminal window"
            case .restoreSession:
                return "Restore windows and tabs from last session"
            case .nothing:
                return "Don't open any windows automatically"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.rtText)

                    Text("Configure application-wide behavior and startup preferences")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
                .padding(.bottom, 8)
            }

            Section("Startup") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When the app launches:")
                        .font(.subheadline)
                        .foregroundColor(Color.rtText)

                    Picker("", selection: $startupBehavior) {
                        ForEach(StartupBehavior.allCases) { behavior in
                            Text(behavior.rawValue).tag(behavior)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text(startupBehavior.description)
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 20)
                }
            }

            Section("Session Management") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Restore sessions on startup", isOn: $restoreSessions)
                        .toggleStyle(.switch)

                    Text("Automatically restore terminal sessions, working directories, and command history")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)
                }
            }

            Section("Default Working Directory") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("~/", text: $directoryInput, prompt: Text("Leave empty for home directory"))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: directoryInput) { newValue in
                                defaultWorkingDirectory = newValue
                            }

                        Button("Browse...") {
                            browseForDirectory()
                        }
                    }

                    Text("New terminal sessions will start in this directory. Supports ~ for home directory.")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
            }

            Section("Confirmations") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Confirm before quitting", isOn: $confirmBeforeQuitting)
                        .toggleStyle(.switch)

                    Text("Show confirmation dialog when quitting with ⌘Q to prevent accidental exits")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)
                }
            }

            Section("Welcome Screen") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show welcome screen on first launch", isOn: $showWelcome)
                        .toggleStyle(.switch)

                    Text("Display helpful tips and quick start guide when launching for the first time")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.rtBackgroundDark)
        .onAppear {
            directoryInput = defaultWorkingDirectory
        }
    }

    // MARK: - Actions

    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Default Working Directory"
        panel.message = "Choose a directory to use as the default working directory for new terminal sessions"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK {
            if let url = panel.url {
                let path = url.path
                // Convert to ~ notation if in home directory
                if path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) {
                    let relativePath = path.replacingOccurrences(
                        of: FileManager.default.homeDirectoryForCurrentUser.path,
                        with: "~"
                    )
                    directoryInput = relativePath
                    defaultWorkingDirectory = relativePath
                } else {
                    directoryInput = path
                    defaultWorkingDirectory = path
                }
            }
        }
    }
}

// MARK: - Preview

struct GeneralPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralPreferencesView()
            .frame(width: 600, height: 500)
    }
}
