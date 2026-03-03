import Foundation

// MARK: - Card Source

/// Tracks the origin of a Kanban card for change preservation
enum CardSource: Codable, Equatable, Hashable {
    /// User created via UI interaction
    case manual

    /// Created from Claude TodoWrite event
    case claude(sourceHash: String)

    /// Imported from external ticket system
    case ticket(ref: String)

    /// Created from sub-agent task
    case subAgent(agentId: UUID, taskHash: String)

    // MARK: - Computed Properties

    /// Whether this card was created manually by the user
    var isManual: Bool {
        if case .manual = self { return true }
        return false
    }

    /// Whether this card originated from Claude
    var isClaude: Bool {
        switch self {
        case .claude, .subAgent:
            return true
        default:
            return false
        }
    }

    /// Extract source hash if available
    var sourceHash: String? {
        switch self {
        case .claude(let hash):
            return hash
        case .subAgent(_, let hash):
            return hash
        default:
            return nil
        }
    }

    /// Extract agent ID if from sub-agent
    var agentId: UUID? {
        if case .subAgent(let id, _) = self {
            return id
        }
        return nil
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .manual:
            return "Manual"
        case .claude:
            return "Claude"
        case .ticket(let ref):
            return "Ticket \(ref)"
        case .subAgent:
            return "Sub-Agent"
        }
    }

    /// Icon name (SF Symbol)
    var iconName: String {
        switch self {
        case .manual:
            return "hand.tap"
        case .claude:
            return "sparkles"
        case .ticket:
            return "ticket"
        case .subAgent:
            return "person.crop.circle.badge.clock"
        }
    }
}

// MARK: - Codable Implementation

extension CardSource {
    private enum CodingKeys: String, CodingKey {
        case type
        case sourceHash
        case ticketRef
        case agentId
        case taskHash
    }

    private enum SourceType: String, Codable {
        case manual
        case claude
        case ticket
        case subAgent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SourceType.self, forKey: .type)

        switch type {
        case .manual:
            self = .manual
        case .claude:
            let hash = try container.decode(String.self, forKey: .sourceHash)
            self = .claude(sourceHash: hash)
        case .ticket:
            let ref = try container.decode(String.self, forKey: .ticketRef)
            self = .ticket(ref: ref)
        case .subAgent:
            let agentId = try container.decode(UUID.self, forKey: .agentId)
            let taskHash = try container.decode(String.self, forKey: .taskHash)
            self = .subAgent(agentId: agentId, taskHash: taskHash)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .manual:
            try container.encode(SourceType.manual, forKey: .type)
        case .claude(let hash):
            try container.encode(SourceType.claude, forKey: .type)
            try container.encode(hash, forKey: .sourceHash)
        case .ticket(let ref):
            try container.encode(SourceType.ticket, forKey: .type)
            try container.encode(ref, forKey: .ticketRef)
        case .subAgent(let agentId, let taskHash):
            try container.encode(SourceType.subAgent, forKey: .type)
            try container.encode(agentId, forKey: .agentId)
            try container.encode(taskHash, forKey: .taskHash)
        }
    }
}
