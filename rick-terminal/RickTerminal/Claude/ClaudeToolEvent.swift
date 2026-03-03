import Foundation

// MARK: - Tool Types

/// Represents the type of tool being invoked by Claude CLI
enum ClaudeToolType: Equatable, Hashable {
    /// Read a file from the filesystem
    case read(path: String)

    /// Write/create a file
    case write(path: String)

    /// Edit an existing file (partial modification)
    case edit(path: String)

    /// Execute a bash command
    case bash(command: String)

    /// Search for files by glob pattern
    case glob(pattern: String)

    /// Search file contents with regex
    case grep(pattern: String, path: String?)

    /// Fetch content from a URL
    case webFetch(url: String)

    /// Search the web
    case webSearch(query: String)

    /// Launch a sub-agent task
    case task(description: String, agentType: String?)

    /// Write to todo list
    case todoWrite

    /// Ask user a question
    case askUser(question: String)

    /// Notebook edit operation
    case notebookEdit(path: String)

    /// Skill invocation
    case skill(name: String)

    /// Unknown or unrecognized tool
    case unknown(name: String, rawParams: String?)

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        case .edit: return "Edit"
        case .bash: return "Bash"
        case .glob: return "Glob"
        case .grep: return "Grep"
        case .webFetch: return "WebFetch"
        case .webSearch: return "WebSearch"
        case .task: return "Task"
        case .todoWrite: return "TodoWrite"
        case .askUser: return "AskUser"
        case .notebookEdit: return "NotebookEdit"
        case .skill: return "Skill"
        case .unknown(let name, _): return name
        }
    }

    /// Short description for status display
    var shortDescription: String {
        switch self {
        case .read(let path):
            return "Reading \(URL(fileURLWithPath: path).lastPathComponent)"
        case .write(let path):
            return "Writing \(URL(fileURLWithPath: path).lastPathComponent)"
        case .edit(let path):
            return "Editing \(URL(fileURLWithPath: path).lastPathComponent)"
        case .bash(let command):
            let truncated = command.prefix(40)
            return "Running: \(truncated)\(command.count > 40 ? "..." : "")"
        case .glob(let pattern):
            return "Finding: \(pattern)"
        case .grep(let pattern, _):
            return "Searching: \(pattern)"
        case .webFetch(let url):
            return "Fetching: \(URL(string: url)?.host ?? url)"
        case .webSearch(let query):
            return "Searching: \(query)"
        case .task(let description, _):
            return description
        case .todoWrite:
            return "Updating todos"
        case .askUser(let question):
            let truncated = question.prefix(30)
            return "Asking: \(truncated)..."
        case .notebookEdit(let path):
            return "Editing notebook: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .skill(let name):
            return "Running skill: \(name)"
        case .unknown(let name, _):
            return "Running: \(name)"
        }
    }

    /// Icon for the tool type (SF Symbol name)
    var iconName: String {
        switch self {
        case .read: return "doc.text"
        case .write: return "doc.badge.plus"
        case .edit: return "pencil"
        case .bash: return "terminal"
        case .glob: return "folder.badge.questionmark"
        case .grep: return "magnifyingglass"
        case .webFetch: return "globe"
        case .webSearch: return "magnifyingglass.circle"
        case .task: return "person.crop.circle.badge.clock"
        case .todoWrite: return "checklist"
        case .askUser: return "questionmark.circle"
        case .notebookEdit: return "book"
        case .skill: return "wand.and.stars"
        case .unknown: return "questionmark.square"
        }
    }

    /// Category for grouping tools
    var category: ToolCategory {
        switch self {
        case .read, .write, .edit, .glob, .notebookEdit:
            return .file
        case .bash:
            return .command
        case .grep, .webSearch:
            return .search
        case .webFetch:
            return .network
        case .task:
            return .agent
        case .todoWrite, .askUser, .skill:
            return .interaction
        case .unknown:
            return .other
        }
    }
}

/// Categories for grouping tool types
enum ToolCategory: String, CaseIterable {
    case file = "File Operations"
    case command = "Commands"
    case search = "Search"
    case network = "Network"
    case agent = "Sub-Agents"
    case interaction = "Interaction"
    case other = "Other"
}

// MARK: - Tool Result

/// Result of a tool execution
enum ToolResult: Equatable {
    /// Tool completed successfully
    case success(output: String?)

    /// Tool completed with truncated output
    case truncated(output: String, totalLines: Int)

    /// Tool found matches (for search tools)
    case matches(count: Int, files: [String])

    /// Tool modified files
    case modified(files: [String])

    /// Tool is still running (for long-running commands)
    case running(progress: String?)
}

// MARK: - Tool Status

/// Current status of a tool invocation
enum ClaudeToolStatus: Equatable {
    /// Tool invocation started
    case started

    /// Tool is currently executing
    case executing(progress: String?)

    /// Tool completed successfully
    case completed(result: ToolResult)

    /// Tool failed with error
    case failed(error: String)

    /// Tool was cancelled
    case cancelled

    /// Whether this status represents a terminal state
    var isTerminal: Bool {
        switch self {
        case .started, .executing:
            return false
        case .completed, .failed, .cancelled:
            return true
        }
    }
}

// MARK: - Tool Event

/// Represents a single tool usage event from Claude CLI output
struct ClaudeToolEvent: Identifiable, Equatable {
    /// Unique identifier for this event
    let id: UUID

    /// When the event occurred
    let timestamp: Date

    /// Type of tool being used
    let toolType: ClaudeToolType

    /// Current status of the tool
    let status: ClaudeToolStatus

    /// Agent ID for multi-agent scenarios (nil for main agent)
    let agentId: UUID?

    /// Session ID this event belongs to
    let sessionId: UUID

    /// Raw output associated with this event (if any)
    let rawOutput: String?

    /// Create a new tool event
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        toolType: ClaudeToolType,
        status: ClaudeToolStatus,
        agentId: UUID? = nil,
        sessionId: UUID,
        rawOutput: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.toolType = toolType
        self.status = status
        self.agentId = agentId
        self.sessionId = sessionId
        self.rawOutput = rawOutput
    }

    /// Create an updated event with new status
    func withStatus(_ newStatus: ClaudeToolStatus, rawOutput: String? = nil) -> ClaudeToolEvent {
        ClaudeToolEvent(
            id: self.id,
            timestamp: Date(),
            toolType: self.toolType,
            status: newStatus,
            agentId: self.agentId,
            sessionId: self.sessionId,
            rawOutput: rawOutput ?? self.rawOutput
        )
    }
}

// MARK: - Aggregate Status

/// Aggregated status for an agent showing recent activity
struct AgentActivityStatus: Identifiable, Equatable {
    /// Agent identifier
    let agentId: UUID

    /// Current operation being performed (if any)
    let currentOperation: ClaudeToolEvent?

    /// Recent operations (most recent first)
    let recentOperations: [ClaudeToolEvent]

    /// Files that have been modified
    let filesModified: Set<String>

    /// Files that have been read
    let filesRead: Set<String>

    /// Number of commands executed
    let commandsRun: Int

    /// Number of errors encountered
    let errorCount: Int

    /// Whether the agent is currently active
    var isActive: Bool {
        currentOperation != nil
    }

    var id: UUID { agentId }

    /// Create an empty status for an agent
    static func empty(agentId: UUID) -> AgentActivityStatus {
        AgentActivityStatus(
            agentId: agentId,
            currentOperation: nil,
            recentOperations: [],
            filesModified: [],
            filesRead: [],
            commandsRun: 0,
            errorCount: 0
        )
    }
}

// MARK: - Extensions for Hashing

extension ToolResult: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .success(let output):
            hasher.combine("success")
            hasher.combine(output)
        case .truncated(let output, let totalLines):
            hasher.combine("truncated")
            hasher.combine(output)
            hasher.combine(totalLines)
        case .matches(let count, let files):
            hasher.combine("matches")
            hasher.combine(count)
            hasher.combine(files)
        case .modified(let files):
            hasher.combine("modified")
            hasher.combine(files)
        case .running(let progress):
            hasher.combine("running")
            hasher.combine(progress)
        }
    }
}

extension ClaudeToolStatus: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .started:
            hasher.combine("started")
        case .executing(let progress):
            hasher.combine("executing")
            hasher.combine(progress)
        case .completed(let result):
            hasher.combine("completed")
            hasher.combine(result)
        case .failed(let error):
            hasher.combine("failed")
            hasher.combine(error)
        case .cancelled:
            hasher.combine("cancelled")
        }
    }
}
