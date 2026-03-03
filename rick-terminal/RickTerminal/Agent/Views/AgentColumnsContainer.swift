import SwiftUI

// MARK: - Agent Columns Container

/// Horizontal scrolling container for agent columns with animations
struct AgentColumnsContainer: View {
    @ObservedObject var manager: AgentColumnsManager

    /// Height of the container (controlled by parent)
    var containerHeight: CGFloat = 280

    /// Whether the container is collapsed (controlled by parent)
    var isCollapsed: Bool = false

    /// Callback when collapse toggle is tapped
    var onToggleCollapse: (() -> Void)? = nil

    /// Spacing between columns
    var columnSpacing: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            containerHeader

            // Columns (hidden when collapsed)
            if !isCollapsed {
                if manager.columns.isEmpty {
                    emptyState
                } else {
                    columnsScrollView
                }
            }
        }
        .background(Color.rtBackgroundDark.opacity(0.95))
        .clipped()
    }

    // MARK: - Header

    private var containerHeader: some View {
        HStack(spacing: 12) {
            // Collapse toggle button
            if let toggle = onToggleCollapse {
                Button(action: toggle) {
                    Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.rtTextSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }

            // Title with icon
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.rtAccentPurple)

                Text("Active Agents")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.rtText)
            }

            // Count badge
            if manager.activeCount > 0 {
                Text("\(manager.activeCount) working")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.rtAccentGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.rtAccentGreen.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Show collapsed indicator when collapsed but has agents
            if isCollapsed && !manager.columns.isEmpty {
                HStack(spacing: -6) {
                    ForEach(manager.workingColumns.prefix(3)) { column in
                        Circle()
                            .fill(column.role.backgroundColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: column.role.iconName)
                                    .font(.system(size: 9))
                                    .foregroundColor(column.role.themeColor)
                            )
                            .overlay(
                                Circle()
                                    .stroke(column.role.borderColor, lineWidth: 1)
                            )
                    }
                    if manager.workingColumns.count > 3 {
                        Circle()
                            .fill(Color.rtBackgroundSecondary)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("+\(manager.workingColumns.count - 3)")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.rtText)
                            )
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
        .background(Color.rtBackgroundSecondary.opacity(0.5))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: 24))
                .foregroundColor(.rtMuted)

            Text("No active agents")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.rtMuted)

            Text("Agents will appear here when spawned by the Task tool")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.rtMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Columns Scroll View

    private var columnsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(manager.sortedColumns) { column in
                    AgentColumnView(column: column)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.columns.count)
    }
}

// MARK: - Compact Agent Columns Container

/// Minimal header-only view when collapsed
struct AgentColumnsCompactView: View {
    @ObservedObject var manager: AgentColumnsManager
    var onExpand: () -> Void

    var body: some View {
        if manager.hasActiveAgents {
            HStack(spacing: 8) {
                // Agent avatars
                HStack(spacing: -8) {
                    ForEach(manager.workingColumns.prefix(3)) { column in
                        AgentAvatarView(column: column)
                    }

                    if manager.workingColumns.count > 3 {
                        Circle()
                            .fill(Color.rtBackgroundSecondary)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("+\(manager.workingColumns.count - 3)")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.rtText)
                            )
                    }
                }

                // Status text
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(manager.activeCount) agent\(manager.activeCount == 1 ? "" : "s") working")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.rtText)

                    if let latest = manager.workingColumns.first?.latestAction {
                        Text(latest.description)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.rtTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Expand button
                Button(action: onExpand) {
                    Image(systemName: "rectangle.expand.vertical")
                        .font(.system(size: 12))
                        .foregroundColor(.rtAccentPurple)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.rtBackgroundSecondary.opacity(0.5))
        }
    }
}

// MARK: - Agent Avatar View

/// Small circular avatar for compact view
struct AgentAvatarView: View {
    @ObservedObject var column: AgentColumn
    @State private var isPulsing: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(column.role.backgroundColor)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(column.role.borderColor, lineWidth: 2)
                .frame(width: 28, height: 28)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0 : 1)

            Image(systemName: column.role.iconName)
                .font(.system(size: 12))
                .foregroundColor(column.role.themeColor)
        }
        .onAppear {
            if column.status.shouldPulse {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }
}

// MARK: - Overlay Style Container

/// Full-width overlay style for placing over terminal
struct AgentColumnsOverlay: View {
    @ObservedObject var manager: AgentColumnsManager
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if isExpanded {
                AgentColumnsContainer(manager: manager)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                AgentColumnsCompactView(manager: manager) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - Previews

#if DEBUG
struct AgentColumnsContainer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full container
            AgentColumnsContainer(manager: AgentColumnsManager.preview)
                .previewDisplayName("Full Container")

            // Empty state
            AgentColumnsContainer(manager: AgentColumnsManager())
                .previewDisplayName("Empty State")

            // Compact view
            AgentColumnsCompactView(manager: AgentColumnsManager.preview) {}
                .previewDisplayName("Compact View")
        }
        .background(Color.rtBackgroundDark)
        .previewLayout(.sizeThatFits)
    }
}
#endif
