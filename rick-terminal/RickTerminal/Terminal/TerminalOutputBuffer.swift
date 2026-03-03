import Foundation

/// High-performance circular buffer for terminal output
/// Avoids O(n²) string concatenation by using a fixed-size ring buffer
final class TerminalOutputBuffer {

    // MARK: - Properties

    /// Maximum number of lines to retain
    let maxLines: Int

    /// Current lines in the buffer (circular array)
    private var lines: [String]

    /// Index of the oldest line in the buffer
    private var head: Int = 0

    /// Number of lines currently in the buffer
    private var count: Int = 0

    /// Thread-safety lock
    private let lock = NSLock()

    /// Pending partial line (no newline yet)
    private var pendingLine: String = ""

    // MARK: - Throttling

    /// Last time the buffer was flushed to observers
    private var lastFlushTime: Date = Date.distantPast

    /// Minimum interval between flushes (16.67ms = 60fps)
    private let minFlushInterval: TimeInterval = 1.0 / 60.0

    /// Pending flush timer
    private var flushTimer: Timer?

    /// Callback for when buffer content changes
    var onContentChanged: ((String) -> Void)?

    // MARK: - Initialization

    /// Initialize buffer with maximum line capacity
    /// - Parameter maxLines: Maximum lines to retain (default 10000)
    init(maxLines: Int = 10000) {
        self.maxLines = maxLines
        self.lines = [String](repeating: "", count: maxLines)
    }

    // MARK: - Public Methods

    /// Append new output to the buffer
    /// - Parameter output: Raw output string (may contain multiple lines)
    func append(_ output: String) {
        lock.lock()
        defer { lock.unlock() }

        // Combine with pending partial line
        let fullOutput = pendingLine + output
        pendingLine = ""

        // Split into lines
        var newLines = fullOutput.components(separatedBy: "\n")

        // If output doesn't end with newline, save the last partial line
        if !output.hasSuffix("\n") && !newLines.isEmpty {
            pendingLine = newLines.removeLast()
        }

        // Add complete lines to buffer
        for line in newLines {
            addLine(line)
        }

        // Schedule throttled flush
        scheduleFlush()
    }

    /// Get all lines as a single string
    /// - Returns: Concatenated buffer contents
    func getContent() -> String {
        lock.lock()
        defer { lock.unlock() }

        var result = [String]()
        result.reserveCapacity(count + 1)

        for i in 0..<count {
            let index = (head + i) % maxLines
            result.append(lines[index])
        }

        // Include pending partial line
        if !pendingLine.isEmpty {
            result.append(pendingLine)
        }

        return result.joined(separator: "\n")
    }

    /// Get the last N lines
    /// - Parameter n: Number of lines to retrieve
    /// - Returns: Array of last N lines
    func getLastLines(_ n: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        let linesToGet = min(n, count)
        var result = [String]()
        result.reserveCapacity(linesToGet)

        let startOffset = count - linesToGet
        for i in 0..<linesToGet {
            let index = (head + startOffset + i) % maxLines
            result.append(lines[index])
        }

        return result
    }

    /// Clear the buffer
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        head = 0
        count = 0
        pendingLine = ""

        // Notify observers
        DispatchQueue.main.async { [weak self] in
            self?.onContentChanged?("")
        }
    }

    /// Get current line count
    var lineCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    // MARK: - Private Methods

    /// Add a single line to the circular buffer
    private func addLine(_ line: String) {
        if count < maxLines {
            // Buffer not full yet
            let index = (head + count) % maxLines
            lines[index] = line
            count += 1
        } else {
            // Buffer full, overwrite oldest
            lines[head] = line
            head = (head + 1) % maxLines
        }
    }

    /// Schedule a throttled flush to observers
    private func scheduleFlush() {
        // Cancel existing timer
        flushTimer?.invalidate()

        let now = Date()
        let elapsed = now.timeIntervalSince(lastFlushTime)

        if elapsed >= minFlushInterval {
            // Enough time has passed, flush immediately
            performFlush()
        } else {
            // Schedule flush for after minimum interval
            let delay = minFlushInterval - elapsed
            flushTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.performFlush()
            }
        }
    }

    /// Perform the actual flush to observers
    private func performFlush() {
        lastFlushTime = Date()

        let content = getContent()

        DispatchQueue.main.async { [weak self] in
            self?.onContentChanged?(content)
        }
    }

    deinit {
        flushTimer?.invalidate()
    }
}

// MARK: - Thread-Safe Wrapper

/// Thread-safe wrapper for accessing buffer content from SwiftUI
@MainActor
final class ObservableTerminalBuffer: ObservableObject {
    @Published private(set) var content: String = ""

    private let buffer: TerminalOutputBuffer

    init(maxLines: Int = 10000) {
        self.buffer = TerminalOutputBuffer(maxLines: maxLines)

        buffer.onContentChanged = { [weak self] newContent in
            self?.content = newContent
        }
    }

    /// Append output (can be called from any thread)
    nonisolated func append(_ output: String) {
        buffer.append(output)
    }

    /// Clear the buffer
    func clear() {
        buffer.clear()
    }

    /// Get line count
    var lineCount: Int {
        buffer.lineCount
    }
}
