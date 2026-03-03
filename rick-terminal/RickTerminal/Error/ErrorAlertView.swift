import SwiftUI

/// Native macOS alert for error presentation
struct ErrorAlertView: ViewModifier {
    @ObservedObject var errorManager = ErrorManager.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: errorManager.activeError?.id) { _ in
                if let presentation = errorManager.activeError {
                    showAlert(for: presentation)
                }
            }
    }

    private func showAlert(for presentation: ErrorPresentation) {
        let alert = NSAlert()
        alert.messageText = presentation.title
        alert.informativeText = presentation.error.userMessage
        alert.alertStyle = alertStyle(for: presentation.error.severity)
        alert.icon = alertIcon(for: presentation.error.severity)

        // Add recovery actions as informative text if available
        if !presentation.error.recoveryActions.isEmpty {
            let actionsText = "\n\nSuggested actions:\n" + presentation.error.recoveryActions.enumerated().map { index, action in
                "\(index + 1). \(action)"
            }.joined(separator: "\n")
            alert.informativeText += actionsText
        }

        // Add buttons
        alert.addButton(withTitle: "OK")

        // Add "View Log" button for errors
        if presentation.error.shouldLog {
            alert.addButton(withTitle: "View Error Log")
        }

        // Show alert and handle response
        DispatchQueue.main.async {
            let response = alert.runModal()

            if response == .alertSecondButtonReturn {
                // User clicked "View Error Log"
                ErrorManager.shared.openErrorLog()
            }

            ErrorManager.shared.dismissError()
        }
    }

    private func alertStyle(for severity: ErrorSeverity) -> NSAlert.Style {
        switch severity {
        case .info:
            return .informational
        case .warning:
            return .warning
        case .error, .critical:
            return .critical
        }
    }

    private func alertIcon(for severity: ErrorSeverity) -> NSImage? {
        let iconName: String
        switch severity {
        case .info:
            iconName = "info.circle.fill"
        case .warning:
            iconName = "exclamationmark.triangle.fill"
        case .error:
            iconName = "xmark.circle.fill"
        case .critical:
            iconName = "xmark.octagon.fill"
        }

        // Create SF Symbol image
        let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        return NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }
}

/// Inline error banner for contextual errors
struct ErrorBannerView: View {
    let error: RTError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Error icon
            Image(systemName: error.severity.icon)
                .font(.title2)
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                // Error message
                Text(error.userMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)

                // Recovery actions
                if !error.recoveryActions.isEmpty {
                    ForEach(Array(error.recoveryActions.prefix(2).enumerated()), id: \.offset) { _, action in
                        Text("• \(action)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        switch error.severity {
        case .info:
            return Color.blue.opacity(0.2)
        case .warning:
            return Color.yellow.opacity(0.2)
        case .error:
            return Color.red.opacity(0.2)
        case .critical:
            return Color.red.opacity(0.3)
        }
    }

    private var borderColor: Color {
        switch error.severity {
        case .info:
            return Color.blue
        case .warning:
            return Color.yellow
        case .error:
            return Color.red
        case .critical:
            return Color.red
        }
    }

    private var iconColor: Color {
        switch error.severity {
        case .info:
            return Color.blue
        case .warning:
            return Color.yellow
        case .error:
            return Color.red
        case .critical:
            return Color.red
        }
    }
}

/// Error state view for empty/error states in UI components
struct ErrorStateView: View {
    let error: RTError
    let retry: (() -> Void)?

    init(error: RTError, retry: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: error.severity.icon)
                .font(.system(size: 48))
                .foregroundColor(iconColor)

            // Error message
            Text(error.userMessage)
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.rtText)
                .multilineTextAlignment(.center)

            // Recovery actions
            if !error.recoveryActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try:")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(Color.rtText.opacity(0.7))

                    ForEach(Array(error.recoveryActions.enumerated()), id: \.offset) { _, action in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(action)
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(Color.rtText.opacity(0.7))
                    }
                }
                .padding()
                .background(Color.rtMuted.opacity(0.1))
                .cornerRadius(8)
            }

            // Retry button
            if let retry = retry {
                Button(action: retry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.rtAccentGreen)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 400)
        .padding()
    }

    private var iconColor: Color {
        switch error.severity {
        case .info:
            return Color.blue
        case .warning:
            return Color.yellow
        case .error:
            return Color.red
        case .critical:
            return Color.red
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply error alert handling to the view
    func errorAlert() -> some View {
        self.modifier(ErrorAlertView())
    }
}

// MARK: - Preview

struct ErrorAlertView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ErrorBannerView(
                error: .claudeNotConfigured,
                onDismiss: {}
            )

            ErrorBannerView(
                error: .filePermissionDenied("/Users/test/file.txt"),
                onDismiss: {}
            )

            ErrorStateView(
                error: .claudeNotFound,
                retry: {}
            )
        }
        .padding()
        .frame(width: 600, height: 500)
        .background(Color.rtBackgroundDark)
    }
}
