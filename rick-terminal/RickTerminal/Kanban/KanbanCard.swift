import Foundation

// MARK: - Card Priority

/// Priority levels for Kanban cards
enum CardPriority: Int, Codable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    static func < (lhs: CardPriority, rhs: CardPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Display name for the priority
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    /// SF Symbol icon for the priority
    var iconName: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .critical: return "exclamationmark.triangle"
        }
    }

    /// Theme-appropriate color name for SwiftUI
    var colorName: String {
        switch self {
        case .low: return "rtText"
        case .medium: return "rtAccentBlue"
        case .high: return "rtAccentPurple"
        case .critical: return "red"
        }
    }
}

// MARK: - Card Status

/// Status of a Kanban card within the workflow
enum CardStatus: String, Codable, CaseIterable {
    case backlog = "backlog"
    case inProgress = "in_progress"
    case review = "review"
    case done = "done"
    case blocked = "blocked"

    /// Display name for the status
    var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .inProgress: return "In Progress"
        case .review: return "Review"
        case .done: return "Done"
        case .blocked: return "Blocked"
        }
    }

    /// SF Symbol icon for the status
    var iconName: String {
        switch self {
        case .backlog: return "tray"
        case .inProgress: return "arrow.right.circle"
        case .review: return "eye"
        case .done: return "checkmark.circle"
        case .blocked: return "xmark.octagon"
        }
    }

    /// Whether this status represents a terminal state
    var isTerminal: Bool {
        self == .done
    }

    /// Whether this status indicates active work
    var isActive: Bool {
        self == .inProgress || self == .review
    }
}

// MARK: - Card Label

/// A label that can be applied to cards for categorization
struct CardLabel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String  // Hex color code (e.g., "#FF5733")

    init(id: UUID = UUID(), name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }

    // MARK: - Preset Labels

    /// Bug/defect label
    static let bug = CardLabel(name: "Bug", color: "#E53935")

    /// Feature request label
    static let feature = CardLabel(name: "Feature", color: "#43A047")

    /// Technical debt label
    static let techDebt = CardLabel(name: "Tech Debt", color: "#FB8C00")

    /// Documentation label
    static let docs = CardLabel(name: "Docs", color: "#1E88E5")

    /// Testing label
    static let testing = CardLabel(name: "Testing", color: "#8E24AA")

    /// Design label
    static let design = CardLabel(name: "Design", color: "#00ACC1")

    /// Security label
    static let security = CardLabel(name: "Security", color: "#D81B60")

    /// Performance label
    static let performance = CardLabel(name: "Performance", color: "#7CB342")

    /// All preset labels
    static var presets: [CardLabel] {
        [.bug, .feature, .techDebt, .docs, .testing, .design, .security, .performance]
    }
}

// MARK: - Kanban Card

/// Represents a single task/ticket on the Kanban board
struct KanbanCard: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var status: CardStatus
    var labels: [CardLabel]
    var priority: CardPriority
    let createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var assignee: String?      // Agent ID or name
    var ticketRef: String?     // External ticket reference (e.g., "RT-022")
    var estimatedPoints: Int?  // Story points for estimation
    var completedAt: Date?     // When card was moved to done
    var source: CardSource     // Origin tracking for change preservation

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        status: CardStatus = .backlog,
        labels: [CardLabel] = [],
        priority: CardPriority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueDate: Date? = nil,
        assignee: String? = nil,
        ticketRef: String? = nil,
        estimatedPoints: Int? = nil,
        completedAt: Date? = nil,
        source: CardSource = .manual
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.labels = labels
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.assignee = assignee
        self.ticketRef = ticketRef
        self.estimatedPoints = estimatedPoints
        self.completedAt = completedAt
        self.source = source
    }

    // MARK: - Mutating Methods

    /// Create a copy with updated timestamp
    func updated() -> KanbanCard {
        var card = self
        card.updatedAt = Date()
        return card
    }

    /// Create a copy with new status
    func withStatus(_ newStatus: CardStatus) -> KanbanCard {
        var card = self
        card.status = newStatus
        card.updatedAt = Date()
        if newStatus == .done && card.completedAt == nil {
            card.completedAt = Date()
        }
        return card
    }

    /// Create a copy with assignee
    func assignedTo(_ agent: String?) -> KanbanCard {
        var card = self
        card.assignee = agent
        card.updatedAt = Date()
        return card
    }

    /// Create a copy with added label
    func withLabel(_ label: CardLabel) -> KanbanCard {
        var card = self
        if !card.labels.contains(label) {
            card.labels.append(label)
            card.updatedAt = Date()
        }
        return card
    }

    /// Create a copy without specified label
    func withoutLabel(_ label: CardLabel) -> KanbanCard {
        var card = self
        card.labels.removeAll { $0.id == label.id }
        card.updatedAt = Date()
        return card
    }

    // MARK: - Computed Properties

    /// Whether the card is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && !status.isTerminal
    }

    /// Age of the card in days
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }

    /// Time spent in current status (if tracking is available)
    var timeInCurrentStatus: TimeInterval? {
        // For now, use time since last update as approximation
        Date().timeIntervalSince(updatedAt)
    }

    /// Whether the card has any labels
    var hasLabels: Bool {
        !labels.isEmpty
    }

    /// Whether the card is assigned
    var isAssigned: Bool {
        assignee != nil && !assignee!.isEmpty
    }
}

// MARK: - Card Sorting

extension KanbanCard {
    /// Sort cards by priority (highest first)
    static func byPriority(_ lhs: KanbanCard, _ rhs: KanbanCard) -> Bool {
        lhs.priority > rhs.priority
    }

    /// Sort cards by creation date (newest first)
    static func byCreatedAt(_ lhs: KanbanCard, _ rhs: KanbanCard) -> Bool {
        lhs.createdAt > rhs.createdAt
    }

    /// Sort cards by due date (earliest first, nil last)
    static func byDueDate(_ lhs: KanbanCard, _ rhs: KanbanCard) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case (nil, nil): return false
        case (nil, _): return false
        case (_, nil): return true
        case let (l?, r?): return l < r
        }
    }

    /// Sort cards by updated date (most recent first)
    static func byUpdatedAt(_ lhs: KanbanCard, _ rhs: KanbanCard) -> Bool {
        lhs.updatedAt > rhs.updatedAt
    }
}

// MARK: - Source Tracking

extension KanbanCard {
    /// Whether this card was created by Claude (auto-generated)
    var isAutoGenerated: Bool {
        source.isClaude
    }

    /// Whether this card was manually created or claimed by user
    var isManuallyManaged: Bool {
        source.isManual
    }

    /// Create a copy with manual source (claim card)
    func claimedByUser() -> KanbanCard {
        var card = self
        card.source = CardSource.manual
        card.updatedAt = Date()
        return card
    }

    /// Check if this card matches a given source hash
    func matchesHash(_ hash: String) -> Bool {
        source.sourceHash == hash
    }
}
