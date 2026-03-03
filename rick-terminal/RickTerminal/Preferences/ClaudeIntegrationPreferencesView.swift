import SwiftUI

/// Claude integration preferences - CLI path, auto-launch, and related settings
struct ClaudeIntegrationPreferencesView: View {
    @ObservedObject var settings = TerminalSettings.shared
    @State private var pathInput: String = ""
    @State private var validationMessage: String = ""
    @State private var validationState: ValidationState = .none
    @State private var isDetecting: Bool = false

    enum ValidationState {
        case none
        case valid
        case invalid
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude Integration")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.rtText)

                    Text("Configure Claude CLI executable path and integration settings")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
                .padding(.bottom, 8)
            }

            Section("Current Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Status:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .frame(width: 100, alignment: .leading)

                        if settings.getClaudeCliPath() != nil {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.rtAccentGreen)
                                Text("Configured")
                                    .foregroundColor(Color.rtText)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color.rtAccentOrange)
                                Text("Not configured")
                                    .foregroundColor(Color.rtTextSecondary)
                            }
                        }
                    }

                    if !settings.claudeCliPath.isEmpty {
                        HStack(alignment: .top) {
                            Text("Path:")
                                .font(.subheadline)
                                .foregroundColor(Color.rtText)
                                .frame(width: 100, alignment: .leading)

                            Text(settings.claudeCliPath)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(Color.rtTextSecondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section("Auto-Detection") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: autoDetectPath) {
                        HStack {
                            if isDetecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(isDetecting ? "Detecting..." : "Auto-Detect Claude CLI")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDetecting)

                    Text("Searches common installation locations:")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• /usr/local/bin/claude")
                        Text("• /opt/homebrew/bin/claude")
                        Text("• ~/.local/bin/claude")
                        Text("• /opt/local/bin/claude")
                    }
                    .font(.caption)
                    .foregroundColor(Color.rtMuted)
                    .padding(.leading, 16)
                }
            }

            Section("Manual Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Enter path to claude executable", text: $pathInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: pathInput) { _ in
                                validationState = .none
                                validationMessage = ""
                            }

                        Button("Browse...") {
                            browseForPath()
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        Button("Validate & Save") {
                            validateAndSavePath()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.rtAccentGreen)
                        .disabled(pathInput.isEmpty)

                        if validationState != .none {
                            HStack(spacing: 4) {
                                Image(systemName: validationState == .valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(validationState == .valid ? Color.rtAccentGreen : .red)

                                Text(validationMessage)
                                    .font(.caption)
                                    .foregroundColor(Color.rtText)
                            }
                        }
                    }

                    Text("Supports ~ for home directory and absolute paths")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
            }

            Section("Auto-Launch Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-launch Claude on terminal start", isOn: $settings.claudeAutoLaunch)
                        .toggleStyle(.switch)

                    Text("Automatically launch Claude CLI when a new terminal session starts")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)

                    if settings.claudeAutoLaunch {
                        Toggle("Show prompt before launching", isOn: $settings.claudeAutoLaunchPrompt)
                            .toggleStyle(.switch)
                            .padding(.leading, 16)

                        Text("Ask for confirmation before auto-launching Claude")
                            .font(.caption)
                            .foregroundColor(Color.rtTextSecondary)
                            .padding(.leading, 32)
                    }
                }
            }

            Section("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Toggle Claude Mode:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .frame(width: 180, alignment: .leading)

                        Text("⌘⇧C")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtAccentGreen)
                    }

                    HStack {
                        Text("Launch Claude CLI:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .frame(width: 180, alignment: .leading)

                        Text("⌘⇧L")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtAccentGreen)
                    }

                    HStack {
                        Text("Exit Claude CLI:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .frame(width: 180, alignment: .leading)

                        Text("⌘⇧E")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtAccentGreen)
                    }
                }
            }

            Section("Actions") {
                Button("Reset Detection") {
                    resetDetection()
                }
                .foregroundColor(.red)

                Text("Clears saved path and allows re-detection")
                    .font(.caption)
                    .foregroundColor(Color.rtTextSecondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.rtBackgroundDark)
        .onAppear {
            if !settings.claudeCliPath.isEmpty {
                pathInput = settings.claudeCliPath
            }
        }
    }

    // MARK: - Actions

    private func autoDetectPath() {
        isDetecting = true
        validationMessage = ""
        validationState = .none

        DispatchQueue.global(qos: .userInitiated).async {
            let detectedPath = ClaudePathDetector.shared.autoDetect()

            DispatchQueue.main.async {
                isDetecting = false

                if let path = detectedPath {
                    settings.claudeCliPath = path
                    pathInput = path
                    validationState = .valid
                    validationMessage = "Claude CLI found and configured"
                } else {
                    validationState = .invalid
                    validationMessage = "Could not auto-detect Claude CLI. Try manual configuration."
                }
            }
        }
    }

    private func validateAndSavePath() {
        let expandedPath = ClaudePathDetector.shared.expandPath(pathInput)

        if ClaudePathDetector.shared.isValidClaudePath(expandedPath) {
            settings.claudeCliPath = expandedPath
            pathInput = expandedPath
            validationState = .valid
            validationMessage = "Path is valid and saved"
        } else {
            validationState = .invalid
            validationMessage = "Invalid path: not executable or not Claude CLI"
        }
    }

    private func browseForPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Claude CLI Executable"
        panel.message = "Choose the claude executable file"
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")

        if panel.runModal() == .OK {
            if let url = panel.url {
                pathInput = url.path
            }
        }
    }

    private func resetDetection() {
        settings.resetClaudeCliDetection()
        pathInput = ""
        validationMessage = ""
        validationState = .none
    }
}

// MARK: - Preview

struct ClaudeIntegrationPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        ClaudeIntegrationPreferencesView()
            .frame(width: 600, height: 700)
    }
}
