import Foundation
import CryptoKit

// MARK: - Todo Status

/// Status of a todo item from Claude's TodoWrite tool
enum TodoStatus: String, Codable, Equatable {
    case pending
    case inProgress = "in_progress"
    case completed

    /// Map to KanbanCard status
    var cardStatus: CardStatus {
        switch self {
        case .pending:
            return .backlog
        case .inProgress:
            return .inProgress
        case .completed:
            return .done
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        }
    }
}

// MARK: - Todo Item

/// Structured representation of a todo item from Claude's TodoWrite output
struct TodoItem: Identifiable, Equatable, Codable {
    /// Unique identifier
    let id: UUID

    /// Task description (imperative form)
    let content: String

    /// Current status
    let status: TodoStatus

    /// Present continuous form for display during execution
    let activeForm: String

    /// Hash for duplicate detection (computed from content)
    let sourceHash: String

    /// When this todo was parsed
    let timestamp: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        content: String,
        status: TodoStatus,
        activeForm: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.status = status
        self.activeForm = activeForm
        self.timestamp = timestamp
        self.sourceHash = Self.computeHash(content: content)
    }

    // MARK: - Hash Computation

    /// Compute deterministic hash for duplicate detection
    /// Uses content only (status changes don't create new card)
    static func computeHash(content: String) -> String {
        let normalized = content
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)

        // Return first 16 characters of hex representation
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Card Conversion

    /// Create a KanbanCard from this todo item
    func toKanbanCard(agentId: UUID? = nil) -> KanbanCard {
        var card = KanbanCard(
            title: content,
            description: "",
            status: status.cardStatus,
            labels: [],
            priority: .medium
        )
        card.source = .claude(sourceHash: sourceHash)
        card.assignee = agentId?.uuidString
        return card
    }
}

// MARK: - TodoWrite Payload

/// Full payload from a TodoWrite event containing all todo items
struct TodoWritePayload: Equatable {
    /// All todos in this payload
    let todos: [TodoItem]

    /// When this payload was parsed
    let timestamp: Date

    /// Agent ID if from sub-agent
    let agentId: UUID?

    // MARK: - Computed Properties

    /// Todos that are pending
    var pendingTodos: [TodoItem] {
        todos.filter { $0.status == .pending }
    }

    /// Todos that are in progress
    var inProgressTodos: [TodoItem] {
        todos.filter { $0.status == .inProgress }
    }

    /// Todos that are completed
    var completedTodos: [TodoItem] {
        todos.filter { $0.status == .completed }
    }

    /// All unique source hashes in this payload
    var sourceHashes: Set<String> {
        Set(todos.map(\.sourceHash))
    }
}

// MARK: - TodoWrite Parser

/// Parser for extracting todo items from Claude's TodoWrite output
final class TodoWriteParser {

    // MARK: - Singleton

    static let shared = TodoWriteParser()

    private init() {}

    // MARK: - Parsing

    /// Parse TodoWrite output to structured payload
    ///
    /// Expected format in rawOutput:
    /// ```
    /// todos:
    /// - content: "Fix the bug"
    ///   status: in_progress
    ///   activeForm: "Fixing the bug"
    /// - content: "Write tests"
    ///   status: pending
    ///   activeForm: "Writing tests"
    /// ```
    ///
    /// Or JSON format:
    /// ```json
    /// {"todos": [{"content": "...", "status": "...", "activeForm": "..."}]}
    /// ```
    func parse(from rawOutput: String, agentId: UUID? = nil) -> TodoWritePayload? {
        // Try JSON parsing first
        if let jsonPayload = parseJSON(from: rawOutput, agentId: agentId) {
            return jsonPayload
        }

        // Fall back to YAML-like parsing
        if let yamlPayload = parseYAMLLike(from: rawOutput, agentId: agentId) {
            return yamlPayload
        }

        // Try line-based parsing for simple lists
        if let linePayload = parseLineFormat(from: rawOutput, agentId: agentId) {
            return linePayload
        }

        return nil
    }

    // MARK: - JSON Parsing

    private func parseJSON(from rawOutput: String, agentId: UUID?) -> TodoWritePayload? {
        // Extract JSON from output (may have surrounding text)
        guard let jsonRange = rawOutput.range(of: "\\{[^{}]*\"todos\"[^{}]*\\}", options: .regularExpression) else {
            // Try array format
            guard let arrayRange = rawOutput.range(of: "\\[[^\\[\\]]*\\]", options: .regularExpression) else {
                return nil
            }
            return parseJSONArray(String(rawOutput[arrayRange]), agentId: agentId)
        }

        let jsonString = String(rawOutput[jsonRange])
        return parseJSONObject(jsonString, agentId: agentId)
    }

    private func parseJSONObject(_ json: String, agentId: UUID?) -> TodoWritePayload? {
        guard let data = json.data(using: .utf8) else { return nil }

        struct TodoJSON: Codable {
            let todos: [TodoItemJSON]
        }

        struct TodoItemJSON: Codable {
            let content: String
            let status: String
            let activeForm: String
        }

        do {
            let decoded = try JSONDecoder().decode(TodoJSON.self, from: data)
            let todos = decoded.todos.compactMap { item -> TodoItem? in
                guard let status = TodoStatus(rawValue: item.status) else { return nil }
                return TodoItem(
                    content: item.content,
                    status: status,
                    activeForm: item.activeForm
                )
            }

            guard !todos.isEmpty else { return nil }
            return TodoWritePayload(todos: todos, timestamp: Date(), agentId: agentId)
        } catch {
            return nil
        }
    }

    private func parseJSONArray(_ json: String, agentId: UUID?) -> TodoWritePayload? {
        guard let data = json.data(using: .utf8) else { return nil }

        struct TodoItemJSON: Codable {
            let content: String
            let status: String
            let activeForm: String
        }

        do {
            let decoded = try JSONDecoder().decode([TodoItemJSON].self, from: data)
            let todos = decoded.compactMap { item -> TodoItem? in
                guard let status = TodoStatus(rawValue: item.status) else { return nil }
                return TodoItem(
                    content: item.content,
                    status: status,
                    activeForm: item.activeForm
                )
            }

            guard !todos.isEmpty else { return nil }
            return TodoWritePayload(todos: todos, timestamp: Date(), agentId: agentId)
        } catch {
            return nil
        }
    }

    // MARK: - YAML-Like Parsing

    private func parseYAMLLike(from rawOutput: String, agentId: UUID?) -> TodoWritePayload? {
        // Pattern: - content: "...", status: ..., activeForm: "..."
        let todoPattern = #"(?:^|\n)\s*-\s*content:\s*"([^"]+)"[\s\S]*?status:\s*(\w+)[\s\S]*?activeForm:\s*"([^"]+)""#

        guard let regex = try? NSRegularExpression(pattern: todoPattern, options: .dotMatchesLineSeparators) else {
            return nil
        }

        let range = NSRange(rawOutput.startIndex..<rawOutput.endIndex, in: rawOutput)
        let matches = regex.matches(in: rawOutput, options: [], range: range)

        var todos: [TodoItem] = []
        for match in matches {
            guard match.numberOfRanges >= 4,
                  let contentRange = Range(match.range(at: 1), in: rawOutput),
                  let statusRange = Range(match.range(at: 2), in: rawOutput),
                  let activeFormRange = Range(match.range(at: 3), in: rawOutput) else {
                continue
            }

            let content = String(rawOutput[contentRange])
            let statusString = String(rawOutput[statusRange])
            let activeForm = String(rawOutput[activeFormRange])

            guard let status = TodoStatus(rawValue: statusString) else { continue }

            todos.append(TodoItem(
                content: content,
                status: status,
                activeForm: activeForm
            ))
        }

        guard !todos.isEmpty else { return nil }
        return TodoWritePayload(todos: todos, timestamp: Date(), agentId: agentId)
    }

    // MARK: - Line Format Parsing

    /// Parse simple line-based format:
    /// [x] Completed task
    /// [>] In progress task
    /// [ ] Pending task
    private func parseLineFormat(from rawOutput: String, agentId: UUID?) -> TodoWritePayload? {
        let lines = rawOutput.components(separatedBy: .newlines)
        var todos: [TodoItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            var status: TodoStatus?
            var content: String?

            if trimmed.hasPrefix("[x]") || trimmed.hasPrefix("[X]") {
                status = .completed
                content = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("[>]") || trimmed.hasPrefix("[-]") {
                status = .inProgress
                content = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("[ ]") {
                status = .pending
                content = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if let range = trimmed.range(of: #"^(\d+)\.\s+(.+)$"#, options: .regularExpression),
                      range == trimmed.startIndex..<trimmed.endIndex {
                // Numbered list format: "1. Task description"
                status = .pending
                // Extract content after the number and dot
                if let dotIndex = trimmed.firstIndex(of: ".") {
                    let afterDot = trimmed[trimmed.index(after: dotIndex)...]
                    content = afterDot.trimmingCharacters(in: .whitespaces)
                }
            }

            if let status = status, let content = content, !content.isEmpty {
                // Generate activeForm by converting imperative to gerund
                let activeForm = Self.toActiveForm(content)
                todos.append(TodoItem(
                    content: content,
                    status: status,
                    activeForm: activeForm
                ))
            }
        }

        guard !todos.isEmpty else { return nil }
        return TodoWritePayload(todos: todos, timestamp: Date(), agentId: agentId)
    }

    // MARK: - Helpers

    /// Convert imperative form to present continuous (activeForm)
    /// "Fix the bug" -> "Fixing the bug"
    /// "Write tests" -> "Writing tests"
    static func toActiveForm(_ imperative: String) -> String {
        let words = imperative.split(separator: " ", maxSplits: 1)
        guard let firstWord = words.first else { return imperative }

        let verb = String(firstWord).lowercased()
        let rest = words.count > 1 ? " " + words[1] : ""

        // Common verb transformations
        let gerund: String
        if verb.hasSuffix("e") && !verb.hasSuffix("ee") {
            gerund = String(verb.dropLast()) + "ing"
        } else if verb.hasSuffix("ie") {
            gerund = String(verb.dropLast(2)) + "ying"
        } else if shouldDoubleConsonant(verb) {
            gerund = verb + verb.last!.description + "ing"
        } else {
            gerund = verb + "ing"
        }

        return gerund.capitalized + rest
    }

    private static func shouldDoubleConsonant(_ verb: String) -> Bool {
        // Simple heuristic for CVC pattern verbs
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        guard verb.count >= 3 else { return false }

        let chars = Array(verb)
        let lastThree = chars.suffix(3)

        guard lastThree.count == 3 else { return false }
        let pattern = lastThree.map { vowels.contains($0) ? "V" : "C" }

        // CVC pattern where last is not w, x, y
        let lastChar = chars.last!
        return pattern == ["C", "V", "C"] && !["w", "x", "y"].contains(lastChar)
    }
}

// MARK: - Extensions

extension ClaudeToolEvent {
    /// Parse TodoWrite payload from this event
    var todoWritePayload: TodoWritePayload? {
        guard case .todoWrite = toolType else { return nil }
        guard let output = rawOutput else { return nil }
        return TodoWriteParser.shared.parse(from: output, agentId: agentId)
    }
}
