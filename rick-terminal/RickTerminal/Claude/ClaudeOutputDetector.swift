import Foundation
import Combine

/// Detects Claude CLI output patterns in terminal stream
/// Works by monitoring terminal output and identifying Claude-specific markers
final class ClaudeOutputDetector {

    // MARK: - Output Events

    enum OutputEvent {
        case claudeResponseStart
        case claudeResponseChunk(String)
        case claudeResponseEnd
        case toolInvocation(String)
        case regularOutput(String)
    }

    // MARK: - Properties

    let eventPublisher: PassthroughSubject<OutputEvent, Never> = PassthroughSubject()

    private var isInClaudeResponse = false
    private var buffer = ""
    private var lineBuffer = ""

    // MARK: - Claude Detection Patterns

    private let claudePromptPattern = #"^\s*claude[>\$]\s*"#
    private let toolInvocationPattern = #"^[⏺●]\s+\w+"#
    private let thinkingStartPattern = #"<thinking>"#
    private let thinkingEndPattern = #"</thinking>"#

    private lazy var claudePromptRegex = try? NSRegularExpression(pattern: claudePromptPattern)
    private lazy var toolRegex = try? NSRegularExpression(pattern: toolInvocationPattern)

    // MARK: - State Machine

    private enum State {
        case idle
        case inClaudePrompt
        case inResponse
        case inThinking
        case inToolExecution
    }

    private var state: State = .idle

    // MARK: - Public API

    /// Process a chunk of terminal output
    func process(_ chunk: String) {
        buffer += chunk

        // Process line by line
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[..<newlineRange.lowerBound])
            buffer.removeSubrange(...newlineRange.upperBound)

            processLine(line)
        }

        // If buffer is getting large without newlines, process it anyway
        if buffer.count > 1000 {
            processLine(buffer)
            buffer = ""
        }
    }

    /// Force flush any remaining buffered content
    func flush() {
        if !buffer.isEmpty {
            processLine(buffer)
            buffer = ""
        }

        if isInClaudeResponse {
            eventPublisher.send(.claudeResponseEnd)
            isInClaudeResponse = false
        }
    }

    /// Reset detector state
    func reset() {
        state = .idle
        isInClaudeResponse = false
        buffer = ""
        lineBuffer = ""
    }

    // MARK: - Line Processing

    private func processLine(_ line: String) {
        // Detect Claude prompt
        if isClaudePrompt(line) {
            state = .inClaudePrompt
            eventPublisher.send(.regularOutput(line))
            return
        }

        // Detect tool invocation
        if isToolInvocation(line) {
            if !isInClaudeResponse {
                eventPublisher.send(.claudeResponseStart)
                isInClaudeResponse = true
            }

            state = .inToolExecution
            eventPublisher.send(.toolInvocation(line))
            eventPublisher.send(.claudeResponseChunk(line))
            return
        }

        // Detect thinking blocks
        if line.contains(thinkingStartPattern) {
            if !isInClaudeResponse {
                eventPublisher.send(.claudeResponseStart)
                isInClaudeResponse = true
            }
            state = .inThinking
            eventPublisher.send(.claudeResponseChunk(line))
            return
        }

        if line.contains(thinkingEndPattern) {
            state = .inResponse
            eventPublisher.send(.claudeResponseChunk(line))
            return
        }

        // Handle based on current state
        switch state {
        case .idle:
            // Regular terminal output
            eventPublisher.send(.regularOutput(line))

        case .inClaudePrompt:
            // User input after Claude prompt
            // Check if it looks like Claude is responding
            if looksLikeClaudeResponse(line) {
                state = .inResponse
                isInClaudeResponse = true
                eventPublisher.send(.claudeResponseStart)
                eventPublisher.send(.claudeResponseChunk(line))
            } else {
                eventPublisher.send(.regularOutput(line))
                state = .idle
            }

        case .inResponse, .inThinking, .inToolExecution:
            // Continue Claude response
            if isEndOfResponse(line) {
                eventPublisher.send(.claudeResponseChunk(line))
                eventPublisher.send(.claudeResponseEnd)
                isInClaudeResponse = false
                state = .idle
            } else {
                eventPublisher.send(.claudeResponseChunk(line))
            }
        }
    }

    // MARK: - Pattern Matching

    private func isClaudePrompt(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return claudePromptRegex?.firstMatch(in: line, range: range) != nil
    }

    private func isToolInvocation(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return toolRegex?.firstMatch(in: trimmed, range: range) != nil
    }

    private func looksLikeClaudeResponse(_ line: String) -> Bool {
        // Check for markdown headers
        if line.hasPrefix("#") || line.hasPrefix("##") {
            return true
        }

        // Check for code blocks
        if line.contains("```") {
            return true
        }

        // Check for common response patterns
        let responsePatterns = [
            "I'll",
            "I will",
            "Let me",
            "Here's",
            "Sure",
            "Based on",
            "The",
            "This"
        ]

        for pattern in responsePatterns {
            if line.hasPrefix(pattern) {
                return true
            }
        }

        return false
    }

    private func isEndOfResponse(_ line: String) -> Bool {
        // End when we see a new prompt
        if isClaudePrompt(line) {
            return true
        }

        // End when we see a regular shell prompt
        let promptPatterns = ["$ ", "% ", "# "]
        for pattern in promptPatterns {
            if line.hasSuffix(pattern) || line.contains(pattern + " ") {
                return true
            }
        }

        return false
    }
}

// MARK: - Convenience Extensions

extension ClaudeOutputDetector {

    /// Create a publisher that only emits Claude response chunks
    var claudeResponsePublisher: AnyPublisher<String, Never> {
        eventPublisher
            .compactMap { event -> String? in
                if case .claudeResponseChunk(let text) = event {
                    return text
                }
                return nil
            }
            .eraseToAnyPublisher()
    }

    /// Create a publisher that emits complete Claude responses
    var completeResponsePublisher: AnyPublisher<String, Never> {
        var buffer = ""

        return eventPublisher
            .compactMap { event -> String? in
                switch event {
                case .claudeResponseStart:
                    buffer = ""
                    return nil

                case .claudeResponseChunk(let text):
                    buffer += text + "\n"
                    return nil

                case .claudeResponseEnd:
                    let result = buffer
                    buffer = ""
                    return result.isEmpty ? nil : result

                default:
                    return nil
                }
            }
            .eraseToAnyPublisher()
    }
}
