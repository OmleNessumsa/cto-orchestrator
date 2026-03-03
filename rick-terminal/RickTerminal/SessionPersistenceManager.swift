import Foundation

/// Represents a persisted session's metadata
struct PersistedSessionState: Codable, Identifiable {
    let id: UUID
    let workingDirectory: String
    let shellType: String // "zsh" or "bash"
    let createdAt: Date
    let lastAccessedAt: Date

    init(id: UUID, workingDirectory: String, shellType: String, createdAt: Date, lastAccessedAt: Date) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.shellType = shellType
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }

    init(from session: ShellSession) {
        self.id = session.id
        self.workingDirectory = session.workingDirectory
        self.shellType = session.shell.rawValue
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
}

/// Manages persistence of shell sessions to disk
class SessionPersistenceManager {
    static let shared = SessionPersistenceManager()

    private let fileManager = FileManager.default
    private let sessionsDirectory: URL
    private let currentSessionFile: URL

    private init() {
        // Store sessions in Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("RickTerminal", isDirectory: true)

        // Create sessions subdirectory
        sessionsDirectory = appDirectory.appendingPathComponent("Sessions", isDirectory: true)
        currentSessionFile = appDirectory.appendingPathComponent("current_session.json")

        // Ensure directory exists
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Current Session Management

    /// Save the current active session ID
    func saveCurrentSession(_ sessionId: UUID?) {
        guard let sessionId = sessionId else {
            try? fileManager.removeItem(at: currentSessionFile)
            return
        }

        let data: [String: String] = ["sessionId": sessionId.uuidString]
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: currentSessionFile)
    }

    /// Load the previously active session ID
    func loadCurrentSessionId() -> UUID? {
        guard let data = try? Data(contentsOf: currentSessionFile),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let sessionIdString = dict["sessionId"],
              let sessionId = UUID(uuidString: sessionIdString) else {
            return nil
        }
        return sessionId
    }

    // MARK: - Session State Persistence

    /// Save a session's state to disk
    func saveSession(_ state: PersistedSessionState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(state)
        let fileURL = sessionFileURL(for: state.id)
        try data.write(to: fileURL)
    }

    /// Save multiple sessions at once
    func saveSessions(_ states: [PersistedSessionState]) throws {
        for state in states {
            try saveSession(state)
        }
    }

    /// Load a specific session by ID
    func loadSession(_ sessionId: UUID) throws -> PersistedSessionState {
        let fileURL = sessionFileURL(for: sessionId)
        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(PersistedSessionState.self, from: data)
    }

    /// Load all saved sessions
    func loadAllSessions() -> [PersistedSessionState] {
        guard let files = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files.compactMap { fileURL in
            guard fileURL.pathExtension == "json",
                  let data = try? Data(contentsOf: fileURL),
                  let session = try? decoder.decode(PersistedSessionState.self, from: data) else {
                return nil
            }
            return session
        }.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    /// Delete a session from disk
    func deleteSession(_ sessionId: UUID) throws {
        let fileURL = sessionFileURL(for: sessionId)
        try fileManager.removeItem(at: fileURL)
    }

    /// Delete multiple sessions
    func deleteSessions(_ sessionIds: [UUID]) throws {
        for sessionId in sessionIds {
            try deleteSession(sessionId)
        }
    }

    /// Delete all sessions
    func deleteAllSessions() throws {
        guard let files = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in files where fileURL.pathExtension == "json" {
            try fileManager.removeItem(at: fileURL)
        }

        // Also clear current session
        try? fileManager.removeItem(at: currentSessionFile)
    }

    /// Clean up old sessions (older than specified days)
    func cleanupOldSessions(olderThanDays days: Int = 30) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let sessions = loadAllSessions()

        let oldSessionIds = sessions
            .filter { $0.lastAccessedAt < cutoffDate }
            .map { $0.id }

        try deleteSessions(oldSessionIds)
    }

    // MARK: - Session Statistics

    /// Get the total number of saved sessions
    var sessionCount: Int {
        return loadAllSessions().count
    }

    /// Check if a session exists
    func sessionExists(_ sessionId: UUID) -> Bool {
        return fileManager.fileExists(atPath: sessionFileURL(for: sessionId).path)
    }

    // MARK: - Private Helpers

    private func sessionFileURL(for sessionId: UUID) -> URL {
        return sessionsDirectory.appendingPathComponent("\(sessionId.uuidString).json")
    }
}

// MARK: - ShellSession Extension for Persistence

extension ShellSession {
    /// Create a persisted state from this session
    func toPersistedState() -> PersistedSessionState {
        return PersistedSessionState(from: self)
    }

    /// Update a persisted state's lastAccessedAt timestamp
    func updatePersistedState(_ state: PersistedSessionState) -> PersistedSessionState {
        return PersistedSessionState(
            id: state.id,
            workingDirectory: state.workingDirectory,
            shellType: state.shellType,
            createdAt: state.createdAt,
            lastAccessedAt: Date()
        )
    }
}
