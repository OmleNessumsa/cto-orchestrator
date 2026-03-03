import Foundation
import Combine

/// Parser for shell integration sequences (OSC 133)
/// Detects command boundaries using terminal escape sequences
/// Similar to how Warp and VS Code terminal detect prompts
final class ShellIntegrationParser {

    // MARK: - Event Types

    /// Events emitted by the parser
    enum ShellEvent {
        /// Prompt is about to be displayed (PRECMD)
        case promptStart

        /// Command is about to execute (PREEXEC)
        case commandStart(command: String)

        /// Command has finished executing
        case commandEnd(exitCode: Int)

        /// Working directory changed
        case directoryChange(path: String)

        /// Shell integration initialized
        case integrationReady
    }

    // MARK: - Properties

    /// Publisher for shell events
    let eventPublisher = PassthroughSubject<ShellEvent, Never>()

    /// Current parser state
    private var state: ParserState = .normal

    /// Buffer for accumulating escape sequence data
    private var sequenceBuffer: String = ""

    /// Buffer for accumulating command text
    private var commandBuffer: String = ""

    /// Current working directory (from OSC 7)
    private(set) var currentDirectory: String?

    /// Whether shell integration is active
    private(set) var isIntegrationActive: Bool = false

    // MARK: - OSC Sequences

    /// OSC 133 sequence markers (FinalTerm/VS Code standard)
    private enum OSC133 {
        /// Mark start of prompt (A)
        static let promptStart = "\u{1b}]133;A\u{07}"

        /// Mark end of prompt, start of command input (B)
        static let commandInputStart = "\u{1b}]133;B\u{07}"

        /// Mark start of command output (C)
        static let commandOutputStart = "\u{1b}]133;C\u{07}"

        /// Mark end of command with exit code (D;exitcode)
        static let commandEndPrefix = "\u{1b}]133;D;"

        /// Regex for detecting command end with exit code
        static let commandEndPattern = try! NSRegularExpression(
            pattern: #"\x1b\]133;D;(\d+)\x07"#,
            options: []
        )

        /// Regex for detecting any OSC 133 sequence
        static let anySequencePattern = try! NSRegularExpression(
            pattern: #"\x1b\]133;([A-Z])(?:;([^\x07]*))?\x07"#,
            options: []
        )
    }

    /// OSC 7 for current directory (standard terminal sequence)
    private enum OSC7 {
        static let pattern = try! NSRegularExpression(
            pattern: #"\x1b\]7;file://[^/]*(.*?)\x07"#,
            options: []
        )
    }

    // MARK: - Parser State

    private enum ParserState {
        case normal
        case inEscapeSequence
        case inOSCSequence
        case inPrompt
        case inCommandInput
        case inCommandOutput
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Process a chunk of terminal output
    /// - Parameter output: Raw terminal output string
    func process(_ output: String) {
        // Check for OSC 133 sequences
        processOSC133(output)

        // Check for OSC 7 (directory change)
        processOSC7(output)
    }

    /// Reset parser state
    func reset() {
        state = .normal
        sequenceBuffer = ""
        commandBuffer = ""
    }

    // MARK: - Private Processing

    private func processOSC133(_ output: String) {
        let range = NSRange(output.startIndex..<output.endIndex, in: output)

        OSC133.anySequencePattern.enumerateMatches(in: output, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let typeRange = Range(match.range(at: 1), in: output) else {
                return
            }

            let type = String(output[typeRange])
            var param: String? = nil

            if match.range(at: 2).location != NSNotFound,
               let paramRange = Range(match.range(at: 2), in: output) {
                param = String(output[paramRange])
            }

            handleOSC133Sequence(type: type, param: param)
        }
    }

    private func handleOSC133Sequence(type: String, param: String?) {
        switch type {
        case "A":
            // Prompt start - shell is about to show prompt
            state = .inPrompt
            eventPublisher.send(.promptStart)

            if !isIntegrationActive {
                isIntegrationActive = true
                eventPublisher.send(.integrationReady)
            }

        case "B":
            // Command input start - prompt ended, user typing command
            state = .inCommandInput
            commandBuffer = ""

        case "C":
            // Command output start - command is executing
            state = .inCommandOutput

            // Emit command start with accumulated command
            let command = commandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !command.isEmpty {
                eventPublisher.send(.commandStart(command: command))
            }
            commandBuffer = ""

        case "D":
            // Command end with exit code
            state = .normal

            if let param = param, let exitCode = Int(param) {
                eventPublisher.send(.commandEnd(exitCode: exitCode))
            } else {
                // Default to exit code 0 if not specified
                eventPublisher.send(.commandEnd(exitCode: 0))
            }

        default:
            break
        }
    }

    private func processOSC7(_ output: String) {
        let range = NSRange(output.startIndex..<output.endIndex, in: output)

        if let match = OSC7.pattern.firstMatch(in: output, options: [], range: range),
           let pathRange = Range(match.range(at: 1), in: output) {
            let path = String(output[pathRange])

            // URL decode the path
            if let decodedPath = path.removingPercentEncoding {
                currentDirectory = decodedPath
                eventPublisher.send(.directoryChange(path: decodedPath))
            }
        }
    }

    /// Accumulate text that might be command input
    /// Call this with text between OSC 133;B and OSC 133;C
    func accumulateCommandInput(_ text: String) {
        if state == .inCommandInput {
            commandBuffer += text
        }
    }
}

// MARK: - Shell Integration Bridge

/// Bridges ShellIntegrationParser with CommandBlockManager
class ShellIntegrationBridge: ObservableObject {

    let parser: ShellIntegrationParser
    let blockManager: CommandBlockManager

    private var cancellables = Set<AnyCancellable>()
    private var currentWorkingDirectory: String

    init(
        parser: ShellIntegrationParser = ShellIntegrationParser(),
        blockManager: CommandBlockManager = CommandBlockManager()
    ) {
        self.parser = parser
        self.blockManager = blockManager
        self.currentWorkingDirectory = FileManager.default.currentDirectoryPath

        setupSubscriptions()
    }

    private func setupSubscriptions() {
        parser.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleShellEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleShellEvent(_ event: ShellIntegrationParser.ShellEvent) {
        switch event {
        case .promptStart:
            // Prompt appearing - previous command finished
            break

        case .commandStart(let command):
            // New command starting
            blockManager.startBlock(
                command: command,
                workingDirectory: currentWorkingDirectory
            )

        case .commandEnd(let exitCode):
            // Command finished
            blockManager.completeBlock(exitCode: exitCode)

        case .directoryChange(let path):
            // Working directory changed
            currentWorkingDirectory = path

        case .integrationReady:
            // Shell integration is now active
            print("[ShellIntegration] Integration ready")
        }
    }

    /// Process terminal output
    func processOutput(_ output: String) {
        parser.process(output)

        // If in command output state, add to current block
        if blockManager.currentBlock != nil {
            // Split by lines and add each
            let lines = output.components(separatedBy: "\n")
            for line in lines where !line.isEmpty {
                blockManager.appendOutput(line)
            }
        }
    }
}
