import Foundation

// MARK: - CTO Event

/// Represents an event from the CTO-Orchestrator system
/// Events are received via webhook from Python scripts
struct CTOEvent: Codable, Identifiable {
    let id: UUID
    let agentId: String
    let eventType: String
    let timestamp: Date
    let data: CTOEventData

    private enum CodingKeys: String, CodingKey {
        case agentId
        case eventType
        case timestamp
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()  // Generate new ID for tracking
        self.agentId = try container.decode(String.self, forKey: .agentId)
        self.eventType = try container.decode(String.self, forKey: .eventType)

        // Parse ISO8601 timestamp
        let timestampString = try container.decode(String.self, forKey: .timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.timestamp = formatter.date(from: timestampString) ?? Date()

        self.data = try container.decode(CTOEventData.self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(eventType, forKey: .eventType)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: timestamp), forKey: .timestamp)

        try container.encode(data, forKey: .data)
    }
}

// MARK: - CTO Event Data

/// Data payload for CTO events
/// Contains fields for various event types (tickets, agents, delegations)
struct CTOEventData: Codable {
    // Ticket events
    var ticketId: String?
    var title: String?
    var type: String?
    var priority: String?
    var status: String?
    var newStatus: String?
    var assignedAgent: String?
    var reason: String?

    // Agent/delegation events
    var agent: String?
    var model: String?
    var filesChanged: [String]?
    var error: String?
    var result: String?

    // Team events
    var teamId: String?
    var members: [String]?

    // Sprint events
    var sprintId: Int?
    var completed: Int?
    var total: Int?

    private enum CodingKeys: String, CodingKey {
        case ticketId = "ticket_id"
        case title, type, priority, status
        case newStatus = "new_status"
        case assignedAgent = "assigned_agent"
        case reason, agent, model
        case filesChanged = "files_changed"
        case error, result
        case teamId = "team_id"
        case members
        case sprintId = "sprint_id"
        case completed, total
    }
}

// MARK: - Event Type Classification

extension CTOEvent {
    /// Event category for routing
    var category: CTOEventCategory {
        if eventType.hasPrefix("cto.ticket") {
            return .ticket
        } else if eventType.hasPrefix("cto.morty") {
            return .morty
        } else if eventType.hasPrefix("cto.team") {
            return .team
        } else if eventType.hasPrefix("cto.sprint") {
            return .sprint
        } else {
            return .other
        }
    }

    /// Whether this is a start/created event
    var isStartEvent: Bool {
        eventType.hasSuffix(".started") || eventType.hasSuffix(".created")
    }

    /// Whether this is an end/completed event
    var isEndEvent: Bool {
        eventType.hasSuffix(".completed") || eventType.hasSuffix(".failed") || eventType.hasSuffix(".timeout")
    }

    /// Whether this event indicates success
    var isSuccess: Bool {
        eventType.hasSuffix(".completed")
    }

    /// Whether this event indicates failure
    var isFailure: Bool {
        eventType.hasSuffix(".failed") || eventType.hasSuffix(".timeout") || eventType.hasSuffix(".blocked")
    }
}

/// Categories for CTO events
enum CTOEventCategory {
    case ticket
    case morty
    case team
    case sprint
    case other
}

// MARK: - Event Type Constants

/// Known CTO event types for matching
enum CTOEventType {
    // Ticket events
    static let ticketCreated = "cto.ticket.created"
    static let ticketStatusChanged = "cto.ticket.status.changed"
    static let ticketCompleted = "cto.ticket.completed"
    static let ticketBlocked = "cto.ticket.blocked"
    static let ticketAssigned = "cto.ticket.assigned"

    // Morty delegation events
    static let mortyDelegationStarted = "cto.morty.delegation.started"
    static let mortyDelegationCompleted = "cto.morty.delegation.completed"
    static let mortyDelegationFailed = "cto.morty.delegation.failed"
    static let mortyDelegationTimeout = "cto.morty.delegation.timeout"

    // Team events
    static let teamMemberStatusChanged = "cto.team.member.status.changed"
    static let teamCreated = "cto.team.created"

    // Sprint events
    static let sprintStarted = "cto.sprint.started"
    static let sprintCompleted = "cto.sprint.completed"
}
