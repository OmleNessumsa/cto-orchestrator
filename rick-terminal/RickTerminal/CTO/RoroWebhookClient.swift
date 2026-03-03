import Foundation
import Network
import Combine

// MARK: - Roro Webhook Client

/// HTTP server that listens for CTO-Orchestrator events via webhook
/// Runs on port 3068 and parses incoming JSON events
final class RoroWebhookClient: ObservableObject {

    // MARK: - Published Properties

    /// Whether the server is currently listening
    @Published private(set) var isListening = false

    /// Number of events received
    @Published private(set) var eventCount = 0

    /// Last error message (if any)
    @Published private(set) var lastError: String?

    // MARK: - Event Publisher

    private let eventSubject = PassthroughSubject<CTOEvent, Never>()

    /// Publisher for received CTO events
    var eventPublisher: AnyPublisher<CTOEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    /// Port to listen on
    let listenPort: UInt16

    // MARK: - Private Properties

    private var listener: NWListener?
    private let listenerQueue = DispatchQueue(
        label: "com.rick.terminal.roro.webhook",
        qos: .utility
    )
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    // MARK: - Initialization

    init(port: UInt16 = 3068) {
        self.listenPort = port
    }

    deinit {
        stop()
    }

    // MARK: - Server Control

    /// Start listening for webhook events
    func start() {
        guard !isListening && listener == nil else {
            NSLog("[RoroWebhookClient] ⏭ Already listening or starting, skipping")
            return
        }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: listenPort))

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleStateChange(state)
                }
            }

            listener?.start(queue: listenerQueue)
            NSLog("[RoroWebhookClient] 🎧 Starting listener on port %d", listenPort)

        } catch {
            DispatchQueue.main.async {
                self.lastError = "Failed to start listener: \(error.localizedDescription)"
            }
            print("[RoroWebhookClient] Failed to start: \(error)")
        }
    }

    /// Stop listening for events
    func stop() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            self.isListening = false
        }
        print("[RoroWebhookClient] Stopped")
    }

    // MARK: - State Handling

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            lastError = nil
            NSLog("[RoroWebhookClient] ✅ Listening on port %d", listenPort)

        case .failed(let error):
            isListening = false
            lastError = "Listener failed: \(error.localizedDescription)"
            NSLog("[RoroWebhookClient] ❌ Failed: %@", String(describing: error))

        case .cancelled:
            isListening = false
            NSLog("[RoroWebhookClient] ⏹ Cancelled")

        case .waiting(let error):
            NSLog("[RoroWebhookClient] ⏳ Waiting: %@", String(describing: error))

        default:
            break
        }
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: listenerQueue)

        // Receive HTTP request data
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let error = error {
                print("[RoroWebhookClient] Receive error: \(error)")
                connection.cancel()
                return
            }

            guard let data = data, let self = self else {
                connection.cancel()
                return
            }

            // Parse and handle the request
            self.handleRequest(data, connection: connection)
        }
    }

    private func handleRequest(_ data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: 400, body: "Invalid request encoding")
            return
        }

        // Parse HTTP body (after \r\n\r\n)
        guard let bodyRange = requestString.range(of: "\r\n\r\n") else {
            sendResponse(connection: connection, status: 400, body: "Invalid HTTP format")
            return
        }

        let bodyString = String(requestString[bodyRange.upperBound...])

        // Handle empty body (health check / OPTIONS)
        if bodyString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendResponse(connection: connection, status: 200, body: "OK")
            return
        }

        // Parse JSON event
        guard let jsonData = bodyString.data(using: .utf8) else {
            sendResponse(connection: connection, status: 400, body: "Invalid JSON encoding")
            return
        }

        do {
            let event = try jsonDecoder.decode(CTOEvent.self, from: jsonData)

            // Debug: write to file
            let debugMsg = "[\(Date())] Received: \(event.eventType) agent=\(event.data.agent ?? "nil")\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                if FileManager.default.fileExists(atPath: debugFile.path) {
                    if let handle = try? FileHandle(forWritingTo: debugFile) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: debugFile)
                }
            }

            // Emit event on main thread
            DispatchQueue.main.async {
                self.eventCount += 1
                self.eventSubject.send(event)
            }

            sendResponse(connection: connection, status: 200, body: "OK")

        } catch {
            // Debug: write error to file
            let debugMsg = "[\(Date())] ERROR: \(error)\nBody: \(bodyString)\n"
            if let data = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("rick_webhook_debug.log")
                try? data.write(to: debugFile)
            }
            sendResponse(connection: connection, status: 400, body: "Parse error: \(error.localizedDescription)")
        }
    }

    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: text/plain\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Debug Support

    #if DEBUG
    /// Simulate receiving an event (for testing)
    func simulateEvent(_ event: CTOEvent) {
        DispatchQueue.main.async {
            self.eventCount += 1
            self.eventSubject.send(event)
        }
    }
    #endif
}
