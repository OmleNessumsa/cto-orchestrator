import SwiftUI
import Combine

// MARK: - Kanban Board View

/// Main Kanban board view with scrollable columns and drag-and-drop card movement
struct KanbanBoardView: View {
    @ObservedObject var board: KanbanBoard
    @ObservedObject var bridge: KanbanEventBridge
    @EnvironmentObject var ctoEventBridge: CTOEventBridge

    @State private var selectedCard: (card: KanbanCard, columnId: UUID)?
    @State private var showCardDetails = false
    @State private var isReloading = false

    /// Tracks the card being dragged and its source column so we can call board.moveCard()
    @State private var draggingCard: KanbanCard?
    @State private var draggingSourceColumnId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Board header
            boardHeader

            Divider()
                .background(Color.rtBorderSubtle)

            // Columns
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(board.columns) { column in
                        KanbanColumnView(
                            board: board,
                            column: column,
                            onCardTap: { card in
                                selectedCard = (card, column.id)
                                showCardDetails = true
                            },
                            onCardClaim: { card in
                                claimCard(card)
                            },
                            onDragStarted: { card in
                                draggingCard = card
                                draggingSourceColumnId = column.id
                            },
                            onDrop: { providers in
                                handleDrop(providers: providers, targetColumnId: column.id)
                            }
                        )
                        .frame(width: 250)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: .infinity)

            // Stats footer
            statsFooter
        }
        .background(Color.rtBackgroundLight.opacity(0.5))
        .sheet(isPresented: $showCardDetails) {
            if let selection = selectedCard {
                SimpleCardDetailView(
                    card: selection.card,
                    onDismiss: { showCardDetails = false }
                )
            }
        }
    }

    // MARK: - Board Header

    private var boardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(board.title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.rtAccentPurple)

                if let projectRef = board.projectRef {
                    Text(projectRef)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)
                }
            }

            Spacer()

            // Sync status
            if let lastSync = bridge.lastSyncAt {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                    Text("Last sync: \(formatSyncTime(lastSync))")
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(.rtMuted)
            }

            // Stats
            HStack(spacing: 8) {
                statBadge(
                    icon: "plus.circle",
                    value: "\(bridge.cardsCreated)",
                    color: .rtAccentGreen
                )

                statBadge(
                    icon: "arrow.up.arrow.down",
                    value: "\(bridge.cardsUpdated)",
                    color: Color(hex: "2196F3")
                )
            }

            // Loaded tickets indicator
            if ctoEventBridge.loadedTicketCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "ticket")
                        .font(.system(size: 8))
                    Text("\(ctoEventBridge.loadedTicketCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.rtAccentGreen)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.rtAccentGreen.opacity(0.15))
                .cornerRadius(4)
            }

            // Reload tickets button
            Button(action: {
                reloadTickets()
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.rtAccentGreen)
                    .font(.system(size: 12))
                    .rotationEffect(.degrees(isReloading ? 360 : 0))
                    .animation(isReloading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isReloading)
            }
            .buttonStyle(.plain)
            .help("Reload tickets from .cto/tickets/")
            .disabled(isReloading)

            // Add card button
            Button(action: {
                // TODO: Show add card dialog
            }) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.rtAccentPurple)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Add new card")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.rtBackgroundDark.opacity(0.5))
    }

    private func reloadTickets() {
        isReloading = true
        ctoEventBridge.reloadTickets()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isReloading = false
        }
    }

    private func statBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }

    // MARK: - Stats Footer

    private var statsFooter: some View {
        HStack(spacing: 16) {
            footerStat(label: "Total Cards", value: "\(board.totalCards)")

            Divider()
                .frame(height: 12)
                .background(Color.rtBorderSubtle)

            if board.totalPoints > 0 {
                footerStat(label: "Points", value: "\(board.totalPoints)")

                Divider()
                    .frame(height: 12)
                    .background(Color.rtBorderSubtle)
            }

            if !board.overdueCards.isEmpty {
                footerStat(
                    label: "Overdue",
                    value: "\(board.overdueCards.count)",
                    color: .red
                )

                Divider()
                    .frame(height: 12)
                    .background(Color.rtBorderSubtle)
            }

            if !board.unassignedCards.isEmpty {
                footerStat(
                    label: "Unassigned",
                    value: "\(board.unassignedCards.count)",
                    color: .rtMuted
                )
            }

            Spacer()

            Text("Updated: \(formatTimestamp(board.updatedAt))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.rtMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.rtBackgroundDark.opacity(0.7))
    }

    private func footerStat(label: String, value: String, color: Color = .rtTextSecondary) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.rtTextSecondary)
            Text(value)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Drag and Drop

    /// Called when items are dropped onto a column.
    /// Resolves the card ID from the provider, finds the source column, and calls board.moveCard().
    /// Returns true on success.
    private func handleDrop(providers: [NSItemProvider], targetColumnId: UUID) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
            guard
                let data = item as? Data,
                let cardIdString = String(data: data, encoding: .utf8),
                let cardId = UUID(uuidString: cardIdString)
            else { return }

            DispatchQueue.main.async {
                // Determine source column
                let sourceColumnId = self.draggingSourceColumnId
                    ?? self.board.findCard(id: cardId)?.columnId

                guard let fromColumnId = sourceColumnId else { return }

                // No-op if dropped on the same column
                guard fromColumnId != targetColumnId else {
                    self.clearDragState()
                    return
                }

                self.board.moveCard(cardId, from: fromColumnId, to: targetColumnId)
                self.clearDragState()
            }
        }

        return true
    }

    private func clearDragState() {
        draggingCard = nil
        draggingSourceColumnId = nil
    }

    // MARK: - Actions

    private func claimCard(_ card: KanbanCard) {
        bridge.markAsManual(card.id)
        HapticFeedback.success()
    }

    // MARK: - Helpers

    private func formatSyncTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Haptic Feedback

enum HapticFeedback {
    static func success() {
        #if os(macOS)
        // macOS does not have UIKit haptics; no-op
        #else
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

// MARK: - Simple Card Detail View

/// Simplified card detail view to avoid freeze issues
struct SimpleCardDetailView: View {
    let card: KanbanCard
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Card Details")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.rtTextPrimary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.rtMuted)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.rtBackgroundDark)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.title)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.rtTextPrimary)

                    if !card.description.isEmpty {
                        Text(card.description)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.rtTextSecondary)
                    }

                    Divider()

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STATUS")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtMuted)
                            Text(card.status.displayName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.rtTextPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("PRIORITY")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtMuted)
                            Text(card.priority.displayName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.rtTextPrimary)
                        }
                    }

                    if let ticketRef = card.ticketRef {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TICKET")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtMuted)
                            Text(ticketRef)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.rtAccentGreen)
                        }
                    }

                    if !card.labels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LABELS")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtMuted)
                            HStack(spacing: 6) {
                                ForEach(card.labels) { label in
                                    Text(label.name)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Color(hex: label.color))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: label.color).opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Spacer()
        }
        .frame(width: 400, height: 400)
        .background(Color.rtBackgroundLight)
    }
}

// MARK: - Preview

#if DEBUG
struct KanbanBoardView_Previews: PreviewProvider {
    static var previews: some View {
        let board = KanbanBoard.standard(projectRef: "rick-terminal")
        let bridge = KanbanEventBridge(board: board)

        if let backlogId = board.columns.first?.id {
            board.addCard(
                KanbanCard(
                    title: "Implement authentication",
                    description: "JWT-based auth with refresh tokens",
                    status: .backlog,
                    labels: [.feature, .security],
                    priority: .high,
                    estimatedPoints: 8
                ),
                to: backlogId
            )
        }

        if let inProgressId = board.columns.first(where: { c in c.title.contains("Progress") })?.id {
            board.addCard(
                KanbanCard(
                    title: "Fix navigation bug",
                    description: "",
                    status: .inProgress,
                    labels: [.bug],
                    priority: .medium,
                    source: .claude(sourceHash: "abc123")
                ),
                to: inProgressId
            )
        }

        return KanbanBoardView(board: board, bridge: bridge)
            .environmentObject(CTOEventBridge())
            .frame(width: 900, height: 600)
            .background(Color.rtBackgroundDark)
    }
}
#endif
