import SwiftUI

// MARK: - Kanban Column View

/// Vertical column displaying cards for a specific status.
/// Accepts drop of KanbanCard IDs (plain-text NSString) and delegates the move to the board.
struct KanbanColumnView: View {
    @ObservedObject var board: KanbanBoard
    let column: KanbanColumn

    var onCardTap: ((KanbanCard) -> Void)?
    var onCardClaim: ((KanbanCard) -> Void)?
    /// Notifies the parent that a drag has begun for a particular card
    var onDragStarted: ((KanbanCard) -> Void)?
    /// Drop handler: called with the dragged card ID string when it lands on this column
    var onDrop: (([NSItemProvider]) -> Bool)?

    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            headerSection

            Divider()
                .background(isDropTargeted ? dropHighlightColor : columnBorderColor)

            // Cards
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(column.cards) { card in
                        KanbanCardView(
                            card: card,
                            onClaim: {
                                onCardClaim?(card)
                            },
                            onTap: {
                                onCardTap?(card)
                            },
                            onDragStarted: { startedCard in
                                onDragStarted?(startedCard)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    if column.cards.isEmpty {
                        emptyStateView
                    }

                    // Extra drop zone at the bottom so users can drag to end of list
                    Color.clear
                        .frame(height: 32)
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .background(
            isDropTargeted
                ? dropHighlightColor.opacity(0.08)
                : Color.rtBackgroundLight.opacity(0.3)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTargeted ? dropHighlightColor : columnBorderColor,
                    lineWidth: isDropTargeted ? 2 : 1
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        .onDrop(of: [.plainText], isTargeted: $isDropTargeted) { providers in
            onDrop?(providers) ?? false
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
            // Column title
            Text(column.title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(columnTitleColor)

            Spacer()

            // Drop indicator badge shown during drag
            if isDropTargeted {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(dropHighlightColor)
                    .transition(.scale.combined(with: .opacity))
            }

            // Card count
            cardCountBadge

            // WIP limit indicator
            if let limit = column.limit {
                limitIndicator(limit: limit)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.rtBackgroundDark.opacity(0.5))
    }

    private var cardCountBadge: some View {
        Text("\(column.cardCount)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(countBadgeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(countBadgeBackground)
            .cornerRadius(4)
    }

    private func limitIndicator(limit: Int) -> some View {
        HStack(spacing: 2) {
            if column.isAtLimit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.red)
            }
            Text("/\(limit)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(column.isAtLimit ? .red : .rtTextSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: isDropTargeted ? "arrow.down.to.line" : "tray")
                .font(.system(size: 20))
                .foregroundColor(isDropTargeted ? dropHighlightColor.opacity(0.7) : .rtMuted.opacity(0.5))

            Text(isDropTargeted ? "Drop here" : "No cards")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(isDropTargeted ? dropHighlightColor.opacity(0.9) : .rtMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    // MARK: - Computed Colors

    private var columnTitleColor: Color {
        if let colorHex = column.color {
            return Color(hex: colorHex)
        }
        return .rtAccentPurple
    }

    private var columnBorderColor: Color {
        if let colorHex = column.color {
            return Color(hex: colorHex).opacity(0.3)
        }
        return .rtBorderSubtle
    }

    /// Accent color used when a card is hovering over this column as a drop target
    private var dropHighlightColor: Color {
        if let colorHex = column.color {
            return Color(hex: colorHex)
        }
        return .rtAccentGreen
    }

    private var countBadgeBackground: Color {
        if column.isAtLimit {
            return .red.opacity(0.2)
        } else if column.cardCount > 0 {
            return columnTitleColor.opacity(0.15)
        } else {
            return .rtMuted.opacity(0.1)
        }
    }

    private var countBadgeTextColor: Color {
        if column.isAtLimit {
            return .red
        } else if column.cardCount > 0 {
            return columnTitleColor
        } else {
            return .rtMuted
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KanbanColumnView_Previews: PreviewProvider {
    static var previews: some View {
        let board = KanbanBoard.standard(projectRef: "rick-terminal")

        let backlogColumn = board.columns.first { $0.title.contains("Backlog") }
        if let columnId = backlogColumn?.id {
            board.addCard(
                KanbanCard(
                    title: "Implement dark mode toggle",
                    description: "Add UI toggle in settings",
                    status: .backlog,
                    labels: [.feature],
                    priority: .medium
                ),
                to: columnId
            )
            board.addCard(
                KanbanCard(
                    title: "Fix navigation bug",
                    description: "",
                    status: .backlog,
                    labels: [.bug],
                    priority: .high,
                    source: .claude(sourceHash: "abc123")
                ),
                to: columnId
            )
        }

        return HStack(spacing: 12) {
            ForEach(board.columns.prefix(3)) { column in
                KanbanColumnView(
                    board: board,
                    column: column,
                    onCardTap: { card in print("Tapped: \(card.title)") },
                    onCardClaim: { card in print("Claimed: \(card.title)") }
                )
                .frame(width: 250)
            }
        }
        .padding()
        .background(Color.rtBackgroundDark)
        .previewLayout(.sizeThatFits)
    }
}
#endif
