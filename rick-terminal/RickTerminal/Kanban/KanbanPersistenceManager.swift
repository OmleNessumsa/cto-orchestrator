import Foundation
import Combine

/// Manages persistence of Kanban boards to disk with debounced auto-save
final class KanbanPersistenceManager {
    static let shared = KanbanPersistenceManager()

    private let fileManager = FileManager.default
    private let boardsDirectory: URL
    private let currentBoardFile: URL

    /// Debounce interval for auto-save (default: 2 seconds)
    private let debounceInterval: TimeInterval

    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Debounce subjects for each board
    private var debounceSaveSubjects: [UUID: PassthroughSubject<Void, Never>] = [:]

    // MARK: - Initialization

    init(debounceInterval: TimeInterval = 2.0) {
        self.debounceInterval = debounceInterval

        // Store boards in Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("RickTerminal", isDirectory: true)

        // Create boards subdirectory
        boardsDirectory = appDirectory.appendingPathComponent("Boards", isDirectory: true)
        currentBoardFile = appDirectory.appendingPathComponent("current_board.json")

        // Ensure directories exist
        try? fileManager.createDirectory(at: boardsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Current Board Management

    /// Save the current active board ID
    func saveCurrentBoardId(_ boardId: UUID?) {
        guard let boardId = boardId else {
            try? fileManager.removeItem(at: currentBoardFile)
            return
        }

        let data: [String: String] = ["boardId": boardId.uuidString]
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: currentBoardFile)
    }

    /// Load the previously active board ID
    func loadCurrentBoardId() -> UUID? {
        guard let data = try? Data(contentsOf: currentBoardFile),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let boardIdString = dict["boardId"],
              let boardId = UUID(uuidString: boardIdString) else {
            return nil
        }
        return boardId
    }

    // MARK: - Board Persistence

    /// Save a board to disk immediately
    func saveBoard(_ board: KanbanBoard) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let codable = board.toCodable()
        let data = try encoder.encode(codable)
        let fileURL = boardFileURL(for: board.id)

        // Write atomically to prevent corruption
        try data.write(to: fileURL, options: .atomic)
    }

    /// Save board with debouncing (auto-save)
    func saveDebounced(_ board: KanbanBoard) {
        // Get or create debounce subject for this board
        let subject = debounceSaveSubjects[board.id] ?? {
            let newSubject = PassthroughSubject<Void, Never>()
            debounceSaveSubjects[board.id] = newSubject

            // Set up debounced save pipeline
            newSubject
                .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    do {
                        try self?.saveBoard(board)
                    } catch {
                        print("Failed to auto-save board \(board.id): \(error)")
                    }
                }
                .store(in: &cancellables)

            return newSubject
        }()

        // Trigger debounced save
        subject.send()
    }

    /// Load a specific board by ID
    func loadBoard(_ boardId: UUID) throws -> KanbanBoard {
        let fileURL = boardFileURL(for: boardId)

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let board = try KanbanBoard.fromJSONData(data)
            return board
        } catch let error as DecodingError {
            // Handle corrupted file gracefully
            throw PersistenceError.corruptedFile(boardId: boardId, underlyingError: error)
        } catch {
            throw error
        }
    }

    /// Load a board with fallback to default on corruption
    func loadBoardOrDefault(_ boardId: UUID, projectRef: String? = nil) -> KanbanBoard {
        do {
            return try loadBoard(boardId)
        } catch PersistenceError.corruptedFile(let corruptedId, _) {
            // Move corrupted file to backup
            backupCorruptedBoard(corruptedId)

            // Return new default board with same ID
            return KanbanBoard.standard(
                title: "Kanban Board (Recovered)",
                projectRef: projectRef
            )
        } catch {
            // File doesn't exist or other error - return new board
            return KanbanBoard.standard(
                title: "Kanban Board",
                projectRef: projectRef
            )
        }
    }

    /// Load all saved boards
    func loadAllBoards() -> [KanbanBoard] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: boardsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files.compactMap { fileURL in
            guard fileURL.pathExtension == "json" else { return nil }

            do {
                let data = try Data(contentsOf: fileURL)
                return try KanbanBoard.fromJSONData(data)
            } catch {
                // Log corrupted file but continue loading others
                print("Skipping corrupted board file: \(fileURL.lastPathComponent)")
                return nil
            }
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Load boards for a specific project
    func loadBoards(forProject projectRef: String) -> [KanbanBoard] {
        loadAllBoards().filter { $0.projectRef == projectRef }
    }

    /// Delete a board from disk
    func deleteBoard(_ boardId: UUID) throws {
        let fileURL = boardFileURL(for: boardId)
        try fileManager.removeItem(at: fileURL)

        // Clean up debounce subject
        debounceSaveSubjects.removeValue(forKey: boardId)
    }

    /// Delete all boards
    func deleteAllBoards() throws {
        guard let files = try? fileManager.contentsOfDirectory(
            at: boardsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for fileURL in files where fileURL.pathExtension == "json" {
            try fileManager.removeItem(at: fileURL)
        }

        // Clear current board
        try? fileManager.removeItem(at: currentBoardFile)

        // Clear debounce subjects
        debounceSaveSubjects.removeAll()
        cancellables.removeAll()
    }

    // MARK: - Board Statistics

    /// Get total number of saved boards
    var boardCount: Int {
        loadAllBoards().count
    }

    /// Check if a board exists
    func boardExists(_ boardId: UUID) -> Bool {
        fileManager.fileExists(atPath: boardFileURL(for: boardId).path)
    }

    // MARK: - Auto-Save Observation

    /// Start observing a board for changes and auto-save
    func observeBoard(_ board: KanbanBoard) {
        // Subscribe to board's objectWillChange publisher
        board.objectWillChange
            .sink { [weak self, weak board] _ in
                guard let self = self, let board = board else { return }
                self.saveDebounced(board)
            }
            .store(in: &cancellables)
    }

    /// Stop observing all boards (cleanup)
    func stopObserving() {
        cancellables.removeAll()
        debounceSaveSubjects.removeAll()
    }

    // MARK: - Corrupted File Handling

    /// Move corrupted board file to backup directory
    private func backupCorruptedBoard(_ boardId: UUID) {
        let sourceURL = boardFileURL(for: boardId)

        let backupDirectory = boardsDirectory.appendingPathComponent("Corrupted", isDirectory: true)
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = backupDirectory.appendingPathComponent(
            "\(boardId.uuidString)_\(timestamp).json"
        )

        try? fileManager.moveItem(at: sourceURL, to: backupURL)
        print("Backed up corrupted board to: \(backupURL.lastPathComponent)")
    }

    // MARK: - Private Helpers

    private func boardFileURL(for boardId: UUID) -> URL {
        boardsDirectory.appendingPathComponent("\(boardId.uuidString).json")
    }
}

// MARK: - Persistence Errors

enum PersistenceError: Error, LocalizedError {
    case corruptedFile(boardId: UUID, underlyingError: Error)
    case fileNotFound(boardId: UUID)
    case encodingFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .corruptedFile(let boardId, let error):
            return "Board file corrupted (ID: \(boardId)): \(error.localizedDescription)"
        case .fileNotFound(let boardId):
            return "Board file not found (ID: \(boardId))"
        case .encodingFailed(let error):
            return "Failed to encode board: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode board: \(error.localizedDescription)"
        }
    }
}
