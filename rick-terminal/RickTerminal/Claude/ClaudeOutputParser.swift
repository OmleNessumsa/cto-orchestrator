import Foundation
import Combine

// MARK: - Parser Delegate Protocol

/// Delegate protocol for receiving parsed tool events
protocol ClaudeOutputParserDelegate: AnyObject {
    /// Called when a tool event is parsed from output
    func parser(_ parser: ClaudeOutputParser, didEmit event: ClaudeToolEvent)

    /// Called when parser encounters an error
    func parser(_ parser: ClaudeOutputParser, didEncounterError error: ParserError)
}

// MARK: - Parser Errors

/// Errors that can occur during parsing
enum ParserError: Error, Equatable {
    case invalidToolFormat(line: String)
    case bufferOverflow(size: Int)
    case unexpectedState(expected: String, got: String)
}

// MARK: - Parser State

/// Internal state machine for the parser
private enum ParserState: Equatable {
    /// Waiting for next tool invocation
    case idle

    /// Currently parsing a tool's output
    case parsingTool(event: ClaudeToolEvent, outputBuffer: String)

    /// Tool completed, emitting result
    case completed(event: ClaudeToolEvent)
}

// MARK: - Claude Output Parser

/// Stateful parser for Claude CLI output that extracts tool usage events
///
/// Usage:
/// ```swift
/// let parser = ClaudeOutputParser(sessionId: session.id)
///
/// // Option 1: Combine subscription
/// parser.eventPublisher
///     .sink { event in
///         print("Tool event: \(event)")
///     }
///     .store(in: &cancellables)
///
/// // Option 2: Delegate pattern
/// parser.delegate = self
///
/// // Feed output chunks as they arrive
/// parser.process(outputChunk)
/// ```
final class ClaudeOutputParser {

    // MARK: - Properties

    /// Delegate for receiving events
    weak var delegate: ClaudeOutputParserDelegate?

    /// Session this parser is associated with
    let sessionId: UUID

    /// Publisher for tool events (Combine integration)
    var eventPublisher: AnyPublisher<ClaudeToolEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Maximum buffer size before forcing completion (64KB)
    var maxBufferSize: Int = 65536

    /// Current parsing state (exposed for testing)
    private(set) var currentEventId: UUID?

    // MARK: - Private Properties

    private let eventSubject = PassthroughSubject<ClaudeToolEvent, Never>()
    private var state: ParserState = .idle
    private var lineBuffer: String = ""
    private let patterns: ClaudeToolPatterns

    // Thread safety
    private let queue = DispatchQueue(label: "com.rick.terminal.parser", qos: .userInitiated)

    // MARK: - Initialization

    init(sessionId: UUID) {
        self.sessionId = sessionId
        self.patterns = ClaudeToolPatterns()
    }

    // MARK: - Public Methods

    /// Process a chunk of output from Claude CLI
    ///
    /// Call this method as output arrives. The parser maintains internal state
    /// to handle output that spans multiple chunks.
    ///
    /// - Parameter chunk: Raw output string to process
    func process(_ chunk: String) {
        queue.async { [weak self] in
            self?.processOnQueue(chunk)
        }
    }

    /// Reset parser state
    ///
    /// Call when starting a new Claude session or recovering from errors.
    func reset() {
        queue.async { [weak self] in
            self?.state = .idle
            self?.lineBuffer = ""
            self?.currentEventId = nil
        }
    }

    /// Force completion of current tool if parsing
    ///
    /// Useful when session ends or times out.
    func forceComplete() {
        queue.async { [weak self] in
            guard let self = self else { return }

            if case .parsingTool(let event, let buffer) = self.state {
                let completedEvent = event.withStatus(
                    .completed(result: .success(output: buffer.isEmpty ? nil : buffer))
                )
                self.emit(completedEvent)
                self.state = .idle
                self.currentEventId = nil
            }
        }
    }

    // MARK: - Private Processing

    private func processOnQueue(_ chunk: String) {
        // Append to line buffer
        lineBuffer += chunk

        // Process complete lines
        while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[..<newlineIndex])
            lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])
            processLine(line)
        }

        // Check buffer overflow
        if case .parsingTool(_, let buffer) = state, buffer.count > maxBufferSize {
            let error = ParserError.bufferOverflow(size: buffer.count)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.parser(self, didEncounterError: error)
            }
            forceComplete()
        }
    }

    private func processLine(_ line: String) {
        // Check for tool invocation start
        if let toolMatch = patterns.matchToolStart(line) {
            handleToolStart(toolMatch, rawLine: line)
            return
        }

        // Check for tool result indicators
        if let resultMatch = patterns.matchToolResult(line) {
            handleToolResult(resultMatch)
            return
        }

        // Otherwise, accumulate output if parsing a tool
        if case .parsingTool(let event, var buffer) = state {
            buffer += line + "\n"
            state = .parsingTool(event: event, outputBuffer: buffer)
        }
    }

    private func handleToolStart(_ match: ToolMatch, rawLine: String) {
        // Complete previous tool if any
        if case .parsingTool(let previousEvent, let buffer) = state {
            let completedEvent = previousEvent.withStatus(
                .completed(result: .success(output: buffer.isEmpty ? nil : buffer))
            )
            emit(completedEvent)
        }

        // Create new event
        let toolType = patterns.parseToolType(name: match.name, params: match.params)
        let event = ClaudeToolEvent(
            toolType: toolType,
            status: .started,
            agentId: match.agentId,
            sessionId: sessionId,
            rawOutput: rawLine
        )

        // Emit started event
        emit(event)

        // Update state
        state = .parsingTool(event: event, outputBuffer: "")
        currentEventId = event.id
    }

    private func handleToolResult(_ result: ToolResultMatch) {
        guard case .parsingTool(let event, let buffer) = state else { return }

        let toolResult: ToolResult
        switch result {
        case .success:
            toolResult = .success(output: buffer.isEmpty ? nil : buffer)
        case .error(let message):
            let completedEvent = event.withStatus(.failed(error: message))
            emit(completedEvent)
            state = .idle
            currentEventId = nil
            return
        case .truncated(let lines):
            toolResult = .truncated(output: buffer, totalLines: lines)
        case .matchCount(let count, let files):
            toolResult = .matches(count: count, files: files)
        }

        let completedEvent = event.withStatus(.completed(result: toolResult))
        emit(completedEvent)
        state = .idle
        currentEventId = nil
    }

    private func emit(_ event: ClaudeToolEvent) {
        // Publish via Combine
        eventSubject.send(event)

        // Notify delegate on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.parser(self, didEmit: event)
        }
    }
}

// MARK: - Tool Match Types

/// Parsed tool invocation match
struct ToolMatch {
    let name: String
    let params: [String: String]
    let agentId: UUID?
}

/// Parsed tool result match
enum ToolResultMatch {
    case success
    case error(String)
    case truncated(Int)
    case matchCount(Int, [String])
}

// MARK: - Pattern Matching (Private)

/// Regex patterns for parsing Claude CLI output
private final class ClaudeToolPatterns {

    // Tool invocation patterns
    // Matches: ⏺ Read(file_path: "/path/to/file")
    // Matches: ● Bash(command: "npm test")
    private let toolStartPattern: NSRegularExpression

    // Parameter extraction
    private let paramPattern: NSRegularExpression

    // Result patterns
    private let errorPattern: NSRegularExpression
    private let truncatedPattern: NSRegularExpression

    init() {
        // Match tool start: ⏺ ToolName(params) or ● ToolName(params)
        // Also handles: Read file_path="/path" format
        toolStartPattern = try! NSRegularExpression(
            pattern: #"^[⏺●]\s*(\w+)\s*(?:\(([^)]*)\)|(.*))?$"#,
            options: []
        )

        // Match key: "value" or key: value patterns
        paramPattern = try! NSRegularExpression(
            pattern: #"(\w+)\s*[:=]\s*"?([^",\)]+)"?"#,
            options: []
        )

        // Match error results
        errorPattern = try! NSRegularExpression(
            pattern: #"(?:Error|Failed|error):\s*(.+)"#,
            options: .caseInsensitive
        )

        // Match truncated output indicator
        truncatedPattern = try! NSRegularExpression(
            pattern: #"output truncated.*?(\d+)\s*lines"#,
            options: .caseInsensitive
        )
    }

    func matchToolStart(_ line: String) -> ToolMatch? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        guard let match = toolStartPattern.firstMatch(in: line, options: [], range: range) else {
            return nil
        }

        // Extract tool name
        guard let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let name = String(line[nameRange])

        // Extract parameters
        var params: [String: String] = [:]

        // Check for parenthesized params
        if let paramsRange = Range(match.range(at: 2), in: line) {
            let paramsString = String(line[paramsRange])
            params = extractParams(from: paramsString)
        }
        // Check for inline params (no parens)
        else if let inlineRange = Range(match.range(at: 3), in: line) {
            let inlineString = String(line[inlineRange])
            params = extractParams(from: inlineString)
        }

        return ToolMatch(name: name, params: params, agentId: nil)
    }

    func matchToolResult(_ line: String) -> ToolResultMatch? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        // Check for error
        if let errorMatch = errorPattern.firstMatch(in: line, options: [], range: range) {
            if let msgRange = Range(errorMatch.range(at: 1), in: line) {
                return .error(String(line[msgRange]))
            }
        }

        // Check for truncated
        if let truncMatch = truncatedPattern.firstMatch(in: line, options: [], range: range) {
            if let countRange = Range(truncMatch.range(at: 1), in: line),
               let count = Int(line[countRange]) {
                return .truncated(count)
            }
        }

        return nil
    }

    func parseToolType(name: String, params: [String: String]) -> ClaudeToolType {
        switch name.lowercased() {
        case "read":
            if let path = params["file_path"] ?? params["path"] {
                return .read(path: path)
            }
            return .unknown(name: name, rawParams: params.description)

        case "write":
            if let path = params["file_path"] ?? params["path"] {
                return .write(path: path)
            }
            return .unknown(name: name, rawParams: params.description)

        case "edit":
            if let path = params["file_path"] ?? params["path"] {
                return .edit(path: path)
            }
            return .unknown(name: name, rawParams: params.description)

        case "bash":
            if let command = params["command"] {
                return .bash(command: command)
            }
            return .bash(command: params.values.first ?? "")

        case "glob":
            if let pattern = params["pattern"] {
                return .glob(pattern: pattern)
            }
            return .unknown(name: name, rawParams: params.description)

        case "grep":
            let pattern = params["pattern"] ?? ""
            let path = params["path"]
            return .grep(pattern: pattern, path: path)

        case "webfetch":
            if let url = params["url"] {
                return .webFetch(url: url)
            }
            return .unknown(name: name, rawParams: params.description)

        case "websearch":
            if let query = params["query"] {
                return .webSearch(query: query)
            }
            return .unknown(name: name, rawParams: params.description)

        case "task":
            let description = params["description"] ?? params["prompt"] ?? "Sub-task"
            let agentType = params["subagent_type"]
            return .task(description: description, agentType: agentType)

        case "todowrite":
            return .todoWrite

        case "askuserquestion":
            let question = params["question"] ?? "Question"
            return .askUser(question: question)

        case "notebookedit":
            if let path = params["notebook_path"] ?? params["path"] {
                return .notebookEdit(path: path)
            }
            return .unknown(name: name, rawParams: params.description)

        case "skill":
            if let skillName = params["skill"] ?? params["name"] {
                return .skill(name: skillName)
            }
            return .unknown(name: name, rawParams: params.description)

        default:
            return .unknown(name: name, rawParams: params.isEmpty ? nil : params.description)
        }
    }

    private func extractParams(from string: String) -> [String: String] {
        var params: [String: String] = [:]
        let range = NSRange(string.startIndex..<string.endIndex, in: string)

        paramPattern.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let keyRange = Range(match.range(at: 1), in: string),
                  let valueRange = Range(match.range(at: 2), in: string) else {
                return
            }

            let key = String(string[keyRange])
            var value = String(string[valueRange]).trimmingCharacters(in: .whitespaces)

            // Remove surrounding quotes if present
            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }

            params[key] = value
        }

        return params
    }
}

// MARK: - Testing Support

#if DEBUG
extension ClaudeOutputParser {
    /// Synchronously process for testing
    func processSync(_ chunk: String) {
        queue.sync {
            processOnQueue(chunk)
        }
    }

    /// Get current state for testing
    var testState: String {
        var result = ""
        queue.sync {
            switch state {
            case .idle:
                result = "idle"
            case .parsingTool(let event, _):
                result = "parsing:\(event.toolType.displayName)"
            case .completed(let event):
                result = "completed:\(event.toolType.displayName)"
            }
        }
        return result
    }
}
#endif
