import SwiftUI

/// Settings view for Claude CLI configuration
struct ClaudeSettingsView: View {
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Claude CLI Configuration")
                        .font(.headline)
                        .foregroundColor(Color.rtAccentGreen)

                    Text("Configure the path to your Claude CLI executable.")
                        .font(.caption)
                        .foregroundColor(Color.rtText.opacity(0.7))

                    // Show error banner if Claude is not configured
                    if settings.getClaudeCliPath() == nil {
                        ErrorBannerView(
                            error: .claudeNotConfigured,
                            onDismiss: {}
                        )
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 8)
            }

            Section("Current Configuration") {
                HStack {
                    Text("Status:")
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
                                .foregroundColor(Color.rtAccentPurple)
                            Text("Not configured")
                                .foregroundColor(Color.rtText.opacity(0.7))
                        }
                    }
                }

                if !settings.claudeCliPath.isEmpty {
                    HStack {
                        Text("Path:")
                            .frame(width: 100, alignment: .leading)
                        Text(settings.claudeCliPath)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtText)
                            .textSelection(.enabled)
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
                    .disabled(isDetecting)

                    Text("Checks common installation locations:")
                        .font(.caption)
                        .foregroundColor(Color.rtText.opacity(0.7))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• /usr/local/bin/claude")
                        Text("• /opt/homebrew/bin/claude")
                        Text("• ~/.local/bin/claude")
                        Text("• /opt/local/bin/claude")
                    }
                    .font(.caption)
                    .foregroundColor(Color.rtText.opacity(0.5))
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
                    }

                    HStack(spacing: 8) {
                        Button("Validate & Save") {
                            validateAndSavePath()
                        }
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
                        .foregroundColor(Color.rtText.opacity(0.7))
                }
            }

            Section("Auto-Launch Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-launch Claude on terminal start", isOn: $settings.claudeAutoLaunch)
                        .toggleStyle(.switch)

                    Text("Automatically launch Claude CLI when a new terminal session starts")
                        .font(.caption)
                        .foregroundColor(Color.rtText.opacity(0.7))

                    if settings.claudeAutoLaunch {
                        Toggle("Show prompt before launching", isOn: $settings.claudeAutoLaunchPrompt)
                            .toggleStyle(.switch)
                            .padding(.leading, 16)

                        Text("Ask for confirmation before auto-launching Claude")
                            .font(.caption)
                            .foregroundColor(Color.rtText.opacity(0.7))
                            .padding(.leading, 16)
                    }
                }
            }

            Section("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Toggle Claude Mode:")
                            .frame(width: 180, alignment: .leading)
                        Text("⌘⇧C")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtAccentGreen)
                    }

                    HStack {
                        Text("Launch Claude CLI:")
                            .frame(width: 180, alignment: .leading)
                        Text("⌘⇧L")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtAccentGreen)
                    }

                    HStack {
                        Text("Exit Claude CLI:")
                            .frame(width: 180, alignment: .leading)
                        Text("⌘⇧E")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.rtAccentGreen)
                    }
                }
                .font(.caption)
            }

            Section("Actions") {
                Button("Reset Detection") {
                    resetDetection()
                }
                .foregroundColor(.red)

                Text("Clears saved path and allows re-detection")
                    .font(.caption)
                    .foregroundColor(Color.rtText.opacity(0.7))
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 700)
        .onAppear {
            // Pre-fill with current path if exists
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

        // Run detection on background thread to avoid UI freeze
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

struct ClaudeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ClaudeSettingsView()
    }
}
