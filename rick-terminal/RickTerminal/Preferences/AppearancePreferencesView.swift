import SwiftUI

/// Appearance preferences - theme, colors, and visual settings
struct AppearancePreferencesView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .rick
    @AppStorage("accentColor") private var accentColor: AccentColor = .green
    @AppStorage("windowOpacity") private var windowOpacity: Double = 0.95
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("enableAnimations") private var enableAnimations: Bool = true
    @AppStorage("reduceMotion") private var reduceMotion: Bool = false

    enum AppTheme: String, CaseIterable, Identifiable {
        case rick = "Rick (Default)"
        case dark = "Pure Dark"
        case dracula = "Dracula"
        case monokai = "Monokai"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .rick:
                return "Rick Terminal's signature purple and green theme"
            case .dark:
                return "Clean pure black background with minimal colors"
            case .dracula:
                return "Popular dark theme with purple accents"
            case .monokai:
                return "Classic code editor theme with vibrant colors"
            }
        }
    }

    enum AccentColor: String, CaseIterable, Identifiable {
        case green = "Green"
        case purple = "Purple"
        case blue = "Blue"
        case orange = "Orange"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .green: return Color.rtAccentGreen
            case .purple: return Color.rtAccentPurple
            case .blue: return Color.rtAccentBlue
            case .orange: return Color.rtAccentOrange
            }
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.rtText)

                    Text("Customize the visual appearance of Rick Terminal")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
                .padding(.bottom, 8)
            }

            Section("Theme") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color scheme:")
                        .font(.subheadline)
                        .foregroundColor(Color.rtText)

                    Picker("", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text(appTheme.description)
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 20)
                }
            }

            Section("Accent Color") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose accent color for highlights, selections, and UI elements:")
                        .font(.subheadline)
                        .foregroundColor(Color.rtText)

                    HStack(spacing: 16) {
                        ForEach(AccentColor.allCases) { accent in
                            Button(action: {
                                accentColor = accent
                            }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.rtText, lineWidth: accentColor == accent ? 2 : 0)
                                        )

                                    Text(accent.rawValue)
                                        .font(.caption)
                                        .foregroundColor(accentColor == accent ? Color.rtText : Color.rtTextSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 20)
                }
            }

            Section("Window Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Window opacity:")
                            .font(.subheadline)
                            .foregroundColor(Color.rtText)

                        Spacer()

                        Text("\(Int(windowOpacity * 100))%")
                            .font(.subheadline)
                            .foregroundColor(Color.rtTextSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }

                    Slider(value: $windowOpacity, in: 0.7...1.0, step: 0.05)
                        .tint(Color.rtAccentGreen)

                    Text("Adjust transparency of terminal window background")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                }
            }

            Section("Editor Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show line numbers in editor", isOn: $showLineNumbers)
                        .toggleStyle(.switch)

                    Text("Display line numbers in the code editor gutter")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)
                }
            }

            Section("Animations") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable UI animations", isOn: $enableAnimations)
                        .toggleStyle(.switch)

                    Text("Smooth transitions and animated UI elements")
                        .font(.caption)
                        .foregroundColor(Color.rtTextSecondary)
                        .padding(.leading, 16)

                    if enableAnimations {
                        Toggle("Reduce motion", isOn: $reduceMotion)
                            .toggleStyle(.switch)
                            .padding(.leading, 16)

                        Text("Minimize animation movement for accessibility")
                            .font(.caption)
                            .foregroundColor(Color.rtTextSecondary)
                            .padding(.leading, 32)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.rtBackgroundDark)
    }
}

// MARK: - Preview

struct AppearancePreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AppearancePreferencesView()
            .frame(width: 600, height: 500)
    }
}
