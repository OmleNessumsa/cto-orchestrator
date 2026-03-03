import SwiftUI

/// Sample view demonstrating all Rick Terminal theme colors
struct ThemePreview: View {
    @Environment(\.rickTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                colorSwatchesSection
                componentExamplesSection
            }
            .padding(24)
        }
        .background(theme.backgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Rick Terminal Theme")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            Text("Color Palette & Components")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(theme.backgroundSecondary)
        .cornerRadius(8)
    }

    // MARK: - Color Swatches

    private var colorSwatchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Swatches")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.accentSuccess)

            VStack(spacing: 12) {
                colorSwatch(name: "Background Dark", color: .rtBackgroundDark, hex: "#0D1010")
                colorSwatch(name: "Background Secondary", color: .rtBackgroundSecondary, hex: "#1E3738")
                colorSwatch(name: "Accent Purple", color: .rtAccentPurple, hex: "#7B78AA")
                colorSwatch(name: "Accent Green", color: .rtAccentGreen, hex: "#7FFC50")
                colorSwatch(name: "Text", color: .rtText, hex: "#FFFFFF")
                colorSwatch(name: "Muted", color: .rtMuted, hex: "#464467")
            }
        }
        .padding(16)
        .background(theme.backgroundSecondary)
        .cornerRadius(8)
    }

    private func colorSwatch(name: String, color: Color, hex: String) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(theme.textMuted.opacity(0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textPrimary)

                Text(hex)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.textMuted)
            }

            Spacer()
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(6)
    }

    // MARK: - Component Examples

    private var componentExamplesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Component Examples")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.accentSuccess)

            VStack(spacing: 16) {
                buttonExample
                terminalExample
                sessionTabExample
                statusIndicatorExample
            }
        }
        .padding(16)
        .background(theme.backgroundSecondary)
        .cornerRadius(8)
    }

    private var buttonExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Buttons")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textMuted)

            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Primary")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.accentPrimary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Text("Success")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.backgroundColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.accentSuccess)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Text("Muted")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.textMuted, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(6)
    }

    private var terminalExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminal Output")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text("$ wubba lubba dub dub")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.terminalPrompt)

                Text("Rick Terminal v1.0.0")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.terminalOutput)

                Text("Ready to burp and compute")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.terminalOutput.opacity(0.8))
            }
            .padding(12)
            .background(theme.backgroundColor)
            .cornerRadius(4)
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(6)
    }

    private var sessionTabExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Tabs")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textMuted)

            HStack(spacing: 8) {
                // Active tab
                HStack(spacing: 4) {
                    Circle()
                        .fill(theme.activeIndicator)
                        .frame(width: 6, height: 6)

                    Text("abc123de")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.textPrimary)

                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentSuccess.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(theme.accentSuccess, lineWidth: 1)
                )

                // Inactive tab
                HStack(spacing: 4) {
                    Circle()
                        .fill(theme.inactiveIndicator)
                        .frame(width: 6, height: 6)

                    Text("def456gh")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.textMuted)

                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(theme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.backgroundColor)
                .cornerRadius(4)
            }
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(6)
    }

    private var statusIndicatorExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status Indicators")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textMuted)

            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.activeIndicator)
                        .frame(width: 8, height: 8)

                    Text("Active")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.accentSuccess)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.textMuted)
                        .frame(width: 8, height: 8)

                    Text("Inactive")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.textMuted)
                }
            }
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(6)
    }
}

// MARK: - Preview

struct ThemePreview_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview()
            .rickTheme()
            .preferredColorScheme(.dark)
    }
}
