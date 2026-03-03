import SwiftUI

// MARK: - Agent Column View

/// Single agent column showing real-time activity
struct AgentColumnView: View {
    @ObservedObject var column: AgentColumn
    @State private var isPulsing: Bool = false

    /// Width of the column
    var columnWidth: CGFloat = 220

    /// Maximum visible actions in log
    var maxVisibleActions: Int = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(column.role.borderColor)

            // Current task
            if let task = column.currentTask {
                currentTaskSection(task)

                Divider()
                    .background(column.role.borderColor)
            }

            // Action log
            actionLogSection

            Spacer(minLength: 0)

            // Footer with stats
            footerSection
        }
        .frame(width: columnWidth)
        .background(column.role.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(column.role.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(column.isDisappearing ? 0 : 1)
        .scaleEffect(column.isAppearing ? 0.9 : 1)
        .opacity(column.isAppearing ? 0.5 : 1)
        .animation(.easeOut(duration: 0.3), value: column.isAppearing)
        .animation(.easeIn(duration: 0.5), value: column.isDisappearing)
        .onAppear {
            if column.status.shouldPulse {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: column.status) { newStatus in
            if newStatus.shouldPulse {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
            // Role icon
            Image(systemName: column.role.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(column.role.themeColor)

            // Name
            Text(column.displayName)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.rtText)
                .lineLimit(1)

            Spacer()

            // Status indicator
            statusIndicator
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(column.status.color)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && column.status.shouldPulse ? 1.3 : 1.0)

            Text(column.status.displayName)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(column.status.color)
        }
    }

    // MARK: - Current Task Section

    private func currentTaskSection(_ task: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Task")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.rtTextSecondary)

            Text(task)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.rtText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Action Log Section

    private var actionLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("Recent Actions")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.rtTextSecondary)

                Spacer()

                Text("\(column.actions.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.rtMuted)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // Action list
            if column.actions.isEmpty {
                Text("No actions yet")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.rtMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(column.actions.prefix(maxVisibleActions)) { action in
                            ActionRowView(action: action)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(maxHeight: CGFloat(maxVisibleActions * 24))
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Time active
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(column.formattedActiveTime)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.rtMuted)

            Spacer()

            // Action counts
            if column.completedActionCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8))
                    Text("\(column.completedActionCount)")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.rtAccentGreen.opacity(0.8))
            }

            if column.failedActionCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                    Text("\(column.failedActionCount)")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(Color(hex: "F44336").opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - Action Row View

/// Single action entry in the log
struct ActionRowView: View {
    let action: AgentAction

    var body: some View {
        HStack(spacing: 6) {
            // Status icon
            Image(systemName: action.statusIconName)
                .font(.system(size: 8))
                .foregroundColor(action.statusColor)
                .frame(width: 10)

            // Tool icon
            Image(systemName: action.toolType.iconName)
                .font(.system(size: 9))
                .foregroundColor(.rtTextSecondary)
                .frame(width: 12)

            // Description
            Text(action.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.rtText)
                .lineLimit(1)

            Spacer()

            // Timestamp
            Text(action.formattedTime)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.rtMuted)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
struct AgentColumnView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = AgentColumnsManager.preview

        HStack(spacing: 12) {
            ForEach(manager.columns) { column in
                AgentColumnView(column: column)
            }
        }
        .padding()
        .background(Color.rtBackgroundDark)
        .previewLayout(.sizeThatFits)
    }
}
#endif
