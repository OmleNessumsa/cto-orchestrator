import Foundation
import SwiftUI

/// Represents a single command execution block (Warp-style)
/// Each block contains a command, its output, and metadata
struct CommandBlock: Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this block
    let id: UUID

    /// The command that was executed
    let command: String

    /// Working directory when command was executed
    let workingDirectory: String

    /// Timestamp when command started
    let startTime: Date

    /// Timestamp when command completed (nil if still running)
    var endTime: Date?

    /// Exit code from the command (nil if still running)
    var exitCode: Int?

    /// Output lines from the command
    var outputLines: [OutputLine]

    /// Current state of the block
    var state: BlockState

    // MARK: - Computed Properties

    /// Duration of command execution
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    /// Formatted duration string
    var durationString: String? {
        guard let duration = duration else { return nil }

        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    /// Whether the command succeeded (exit code 0)
    var succeeded: Bool {
        exitCode == 0
    }

    /// Whether the command is still running
    var isRunning: Bool {
        state == .running
    }

    /// Full output as a single string
    var outputText: String {
        outputLines.map { $0.text }.joined(separator: "\n")
    }

    /// Truncated output for preview
    var previewOutput: String {
        let maxLines = 5
        let lines = outputLines.prefix(maxLines).map { $0.text }
        let result = lines.joined(separator: "\n")

        if outputLines.count > maxLines {
            return result + "\n... (\(outputLines.count - maxLines) more lines)"
        }
        return result
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        command: String,
        workingDirectory: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        exitCode: Int? = nil,
        outputLines: [OutputLine] = [],
        state: BlockState = .running
    ) {
        self.id = id
        self.command = command
        self.workingDirectory = workingDirectory
        self.startTime = startTime
        self.endTime = endTime
        self.exitCode = exitCode
        self.outputLines = outputLines
        self.state = state
    }

    // MARK: - Mutation Methods

    /// Add output line to the block
    mutating func appendOutput(_ text: String, type: OutputLine.OutputType = .stdout) {
        let line = OutputLine(text: text, type: type)
        outputLines.append(line)
    }

    /// Mark the block as completed
    mutating func complete(exitCode: Int) {
        self.endTime = Date()
        self.exitCode = exitCode
        self.state = exitCode == 0 ? .completed : .failed
    }

    /// Mark the block as cancelled
    mutating func cancel() {
        self.endTime = Date()
        self.state = .cancelled
    }
}

// MARK: - Block State

/// Current state of a command block
enum BlockState: String, Equatable, CaseIterable {
    /// Command is currently executing
    case running

    /// Command completed successfully (exit code 0)
    case completed

    /// Command failed (non-zero exit code)
    case failed

    /// Command was cancelled/interrupted
    case cancelled

    /// State color for UI
    var color: Color {
        switch self {
        case .running:
            return .rtAccentBlue
        case .completed:
            return .rtAccentGreen
        case .failed:
            return .rtAccentOrange
        case .cancelled:
            return .rtTextSecondary
        }
    }

    /// State icon
    var iconName: String {
        switch self {
        case .running:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "stop.circle.fill"
        }
    }
}

// MARK: - Output Line

/// A single line of output from a command
struct OutputLine: Identifiable, Equatable {
    let id: UUID
    let text: String
    let type: OutputType
    let timestamp: Date

    /// Type of output
    enum OutputType: String, Equatable {
        case stdout
        case stderr
        case system // For system messages like "Process terminated"

        var color: Color {
            switch self {
            case .stdout:
                return .rtTextPrimary
            case .stderr:
                return .rtAccentOrange
            case .system:
                return .rtTextSecondary
            }
        }
    }

    init(id: UUID = UUID(), text: String, type: OutputType = .stdout, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
    }
}

// MARK: - Command Block Manager

/// Manages a collection of command blocks for a session
class CommandBlockManager: ObservableObject {
    @Published private(set) var blocks: [CommandBlock] = []
    @Published private(set) var currentBlock: CommandBlock?

    /// Maximum number of blocks to retain
    let maxBlocks: Int

    init(maxBlocks: Int = 1000) {
        self.maxBlocks = maxBlocks
    }

    /// Start a new command block
    func startBlock(command: String, workingDirectory: String) {
        // Complete previous block if still running
        if var current = currentBlock {
            current.complete(exitCode: -1) // Unknown exit code
            blocks.append(current)
        }

        // Create new block
        currentBlock = CommandBlock(
            command: command,
            workingDirectory: workingDirectory
        )

        // Trim old blocks if needed
        trimBlocks()
    }

    /// Add output to the current block
    func appendOutput(_ text: String, type: OutputLine.OutputType = .stdout) {
        currentBlock?.appendOutput(text, type: type)
    }

    /// Complete the current block
    func completeBlock(exitCode: Int) {
        guard var current = currentBlock else { return }

        current.complete(exitCode: exitCode)
        blocks.append(current)
        currentBlock = nil

        trimBlocks()
    }

    /// Cancel the current block
    func cancelBlock() {
        guard var current = currentBlock else { return }

        current.cancel()
        blocks.append(current)
        currentBlock = nil
    }

    /// Get block by ID
    func getBlock(_ id: UUID) -> CommandBlock? {
        if currentBlock?.id == id {
            return currentBlock
        }
        return blocks.first { $0.id == id }
    }

    /// Clear all blocks
    func clear() {
        blocks.removeAll()
        currentBlock = nil
    }

    /// Get recent blocks
    func recentBlocks(_ count: Int) -> [CommandBlock] {
        let recent = blocks.suffix(count)
        if let current = currentBlock {
            return Array(recent) + [current]
        }
        return Array(recent)
    }

    // MARK: - Private

    private func trimBlocks() {
        if blocks.count > maxBlocks {
            let excess = blocks.count - maxBlocks
            blocks.removeFirst(excess)
        }
    }
}
