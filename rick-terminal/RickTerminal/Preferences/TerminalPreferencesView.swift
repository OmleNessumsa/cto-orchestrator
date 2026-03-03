import SwiftUI

/// Terminal preferences - font, cursor, colors, and terminal behavior
struct TerminalPreferencesView: View {
    @ObservedObject var settings = TerminalSettings.shared
    @AppStorage("scrollbackLines") private var scrollbackLines: Int = 10000
    @AppStorage("enableBell") private var enableBell: Bool = false
    @AppStorage("bellStyle") private var bellStyle: BellStyle = .visual
    @AppStorage("closeOnExit") private var closeOnExit: Bool = true
    @AppStorage("enableMouseReporting") private var enableMouseReporting: Bool = true

    enum BellStyle: String, CaseIterable, Identifiable {
        case visual = "Visual Flash"
        case sound = "Sound"
        case both = "Both"

        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terminal")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.rtText)

                    Text("Configure terminal appearance and behavior")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
                .padding(.bottom, 8)
            }

            Section("Font") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font size:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .frame(width: 120, alignment: .leading)

                        Slider(
                            value: $settings.fontSize,
                            in: TerminalSettings.minFontSize...TerminalSettings.maxFontSize,
                            step: 1.0
                        )
                        .tint(Color.rtAccentGreen)

                        Text("\(Int(settings.fontSize)) pt")
                            .font(.subheadline)
                            .foregroundColor(Color.rtTextSecondary)
                            .frame(width: 60, alignment: .trailing)
                    }

                    Text("Current font: \(settings.terminalFont.fontName)")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)

                    HStack {
                        Button("Reset to Default") {
                            settings.resetFontSize()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
            }

            Section("Cursor") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cursor style:")
                        .font(.subheadline)
                        .foregroundColor(Color.rtText)

                    Picker("", selection: $settings.cursorStyle) {
                        ForEach(TerminalSettings.CursorStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Divider()
                        .padding(.vertical, 4)

                    Toggle("Cursor blink", isOn: $settings.cursorBlink)
                        .toggleStyle(.switch)

                    Text("Enable or disable cursor blinking animation")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)
                }
            }

            Section("Scrollback") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Scrollback lines:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .frame(width: 120, alignment: .leading)

                        TextField("", value: $scrollbackLines, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)

                        Stepper("", value: $scrollbackLines, in: 100...100000, step: 1000)
                            .labelsHidden()
                    }

                    Text("Number of lines to keep in scrollback buffer. Higher values use more memory.")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
            }

            Section("Bell") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable bell", isOn: $enableBell)
                        .toggleStyle(.switch)

                    if enableBell {
                        Text("Bell style:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)
                            .padding(.leading, 16)
                            .padding(.top, 8)

                        Picker("", selection: $bellStyle) {
                            ForEach(BellStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .padding(.leading, 16)
                    }
                }
            }

            Section("Behavior") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Close tab when shell exits", isOn: $closeOnExit)
                        .toggleStyle(.switch)

                    Text("Automatically close terminal tab when the shell process exits")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)

                    Divider()
                        .padding(.vertical, 4)

                    Toggle("Enable mouse reporting", isOn: $enableMouseReporting)
                        .toggleStyle(.switch)

                    Text("Allow terminal programs to receive mouse events (required for some TUI apps)")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)
                }
            }

            Section("ANSI Colors") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Terminal color palette (Rick Terminal theme):")
                        .font(.subheadline)
                        .foregroundColor(Color.rtText)

                    // Normal colors
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Normal colors:")
                            .font(.caption)
                            .foregroundColor(Color.rtTextSecondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(0..<8, id: \.self) { index in
                                colorSwatch(settings.ansiColors[index], name: colorName(for: index))
                            }
                        }
                    }

                    // Bright colors
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bright colors:")
                            .font(.caption)
                            .foregroundColor(Color.rtTextSecondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(8..<16, id: \.self) { index in
                                colorSwatch(settings.ansiColors[index], name: colorName(for: index))
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.rtBackgroundDark)
    }

    // MARK: - Helpers

    private func colorSwatch(_ color: NSColor, name: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(color))
                .frame(height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.rtBorderSubtle, lineWidth: 1)
                )

            Text(name)
                .font(.caption2)
                .foregroundColor(Color.rtTextSecondary)
        }
    }

    private func colorName(for index: Int) -> String {
        let names = [
            "Black", "Red", "Green", "Yellow",
            "Blue", "Magenta", "Cyan", "White",
            "Br Black", "Br Red", "Br Green", "Br Yellow",
            "Br Blue", "Br Magenta", "Br Cyan", "Br White"
        ]
        return names[safe: index] ?? "Color \(index)"
    }
}

// MARK: - Array Safe Subscript Extension

private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

struct TerminalPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalPreferencesView()
            .frame(width: 600, height: 700)
    }
}
