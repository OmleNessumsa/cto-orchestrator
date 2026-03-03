import Foundation

// MARK: - CTO Ticket

/// Represents a ticket from the .cto/tickets/ folder
struct CTOTicket: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var description: String
    var type: TicketType
    var status: TicketStatus
    var priority: TicketPriority
    var assignedAgent: String?
    var parentTicket: String?
    var dependencies: [String]
    var acceptanceCriteria: [String]
    var estimatedComplexity: String?
    var teamMode: String?
    var teamTemplate: String?
    var teamId: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var agentOutput: String?
    var reviewNotes: String?
    var filesTouched: [String]

    private enum CodingKeys: String, CodingKey {
        case id, title, description, type, status, priority
        case assignedAgent = "assigned_agent"
        case parentTicket = "parent_ticket"
        case dependencies
        case acceptanceCriteria = "acceptance_criteria"
        case estimatedComplexity = "estimated_complexity"
        case teamMode = "team_mode"
        case teamTemplate = "team_template"
        case teamId = "team_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case agentOutput = "agent_output"
        case reviewNotes = "review_notes"
        case filesTouched = "files_touched"
    }

    // MARK: - Ticket Type

    enum TicketType: String, Codable, CaseIterable {
        case epic
        case feature
        case task
        case bug
        case spike

        var displayName: String {
            rawValue.capitalized
        }

        var labelColor: String {
            switch self {
            case .epic: return "#9C27B0"      // Purple
            case .feature: return "#43A047"   // Green
            case .task: return "#1E88E5"      // Blue
            case .bug: return "#E53935"       // Red
            case .spike: return "#FF9800"     // Orange
            }
        }
    }

    // MARK: - Ticket Status

    enum TicketStatus: String, CaseIterable {
        case todo
        case backlog  // Alias for todo
        case inProgress
        case inReview
        case blocked
        case done

        var cardStatus: CardStatus {
            switch self {
            case .todo, .backlog: return .backlog
            case .inProgress: return .inProgress
            case .inReview: return .review
            case .blocked: return .blocked
            case .done: return .done
            }
        }
    }

    // MARK: - Ticket Priority

    enum TicketPriority: String, Codable, CaseIterable {
        case critical
        case high
        case medium
        case low

        var cardPriority: CardPriority {
            switch self {
            case .critical: return .critical
            case .high: return .high
            case .medium: return .medium
            case .low: return .low
            }
        }
    }
}

// MARK: - TicketStatus Codable

extension CTOTicket.TicketStatus: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value.lowercased() {
        case "todo", "backlog":
            self = .todo
        case "in_progress", "inprogress", "in-progress":
            self = .inProgress
        case "in_review", "inreview", "in-review", "review":
            self = .inReview
        case "blocked":
            self = .blocked
        case "done", "completed", "closed":
            self = .done
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown status: \(value)"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .todo, .backlog:
            try container.encode("todo")
        case .inProgress:
            try container.encode("in_progress")
        case .inReview:
            try container.encode("in_review")
        case .blocked:
            try container.encode("blocked")
        case .done:
            try container.encode("done")
        }
    }
}

// MARK: - Ticket to Card Conversion

extension CTOTicket {
    /// Convert ticket to a KanbanCard
    func toKanbanCard() -> KanbanCard {
        let label = CardLabel(name: type.displayName, color: type.labelColor)

        return KanbanCard(
            title: "[\(id)] \(title)",
            description: description,
            status: status.cardStatus,
            labels: [label],
            priority: priority.cardPriority,
            createdAt: createdAt,
            updatedAt: updatedAt,
            assignee: assignedAgent,
            ticketRef: id,
            completedAt: completedAt,
            source: .ticket(ref: id)
        )
    }
}

// MARK: - Ticket Loader

/// Loads tickets from the .cto/tickets/ folder
final class CTOTicketLoader {

    /// ISO8601 formatter that handles fractional seconds
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback formatter without fractional seconds
    private static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Load all tickets from a project's .cto/tickets/ folder
    static func loadTickets(from projectURL: URL) -> [CTOTicket] {
        let ticketsDir = projectURL.appendingPathComponent(".cto/tickets")

        guard FileManager.default.fileExists(atPath: ticketsDir.path) else {
            print("[CTOTicketLoader] No tickets directory at: \(ticketsDir.path)")
            return []
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: ticketsDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "json" }

            var tickets: [CTOTicket] = []
            let decoder = JSONDecoder()

            // Custom date decoding that handles fractional seconds
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try with fractional seconds first
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Fallback to without fractional seconds
                if let date = iso8601FallbackFormatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Cannot parse date: \(dateString)"
                    )
                )
            }

            for fileURL in fileURLs {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let ticket = try decoder.decode(CTOTicket.self, from: data)
                    tickets.append(ticket)
                    print("[CTOTicketLoader] OK: \(fileURL.lastPathComponent) - \(ticket.status)")
                } catch {
                    print("[CTOTicketLoader] FAILED: \(fileURL.lastPathComponent)")
                    print("[CTOTicketLoader] Error: \(error)")
                }
            }

            // Sort by ID (RT-001, RT-002, etc.)
            tickets.sort { ticket1, ticket2 in
                let num1 = Int(ticket1.id.replacingOccurrences(of: "RT-", with: "")) ?? 0
                let num2 = Int(ticket2.id.replacingOccurrences(of: "RT-", with: "")) ?? 0
                return num1 < num2
            }

            print("[CTOTicketLoader] Loaded \(tickets.count) tickets from \(ticketsDir.path)")
            return tickets

        } catch {
            print("[CTOTicketLoader] Failed to read tickets directory: \(error)")
            return []
        }
    }

    /// Watch for ticket changes (future enhancement)
    static func watchTickets(at projectURL: URL, onChange: @escaping ([CTOTicket]) -> Void) {
        // TODO: Implement FSEvents watching for real-time updates
    }
}
