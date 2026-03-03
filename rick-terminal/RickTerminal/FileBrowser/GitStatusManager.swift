import Foundation
import Combine

/// Git file status codes as parsed from `git status --porcelain`
enum GitFileStatus: Equatable {
    case modified        // M - staged or unstaged modification
    case added           // A - new file staged for commit
    case deleted         // D - deleted file
    case renamed         // R - renamed file
    case untracked       // ? - not tracked by git
    case ignored         // ! - ignored by .gitignore
    case conflicted      // U/C - merge conflict
    case clean           // no change

    /// Color hex string for this status (matches Rick Terminal theme)
    var colorHex: String {
        switch self {
        case .modified:   return "FF9F40" // orange/yellow
        case .added:      return "7FFC50" // green
        case .deleted:    return "FF5555" // red
        case .renamed:    return "FF9F40" // orange
        case .untracked:  return "9CA3AF" // grey
        case .ignored:    return "6B7280" // dark grey
        case .conflicted: return "FF5555" // red
        case .clean:      return "9CA3AF" // default
        }
    }

    /// Short badge string displayed next to the file name
    var badge: String? {
        switch self {
        case .modified:   return "M"
        case .added:      return "A"
        case .deleted:    return "D"
        case .renamed:    return "R"
        case .untracked:  return "U"
        case .ignored:    return nil
        case .conflicted: return "!"
        case .clean:      return nil
        }
    }
}

/// Represents a git repository at a specific root path
struct GitRepository {
    let rootURL: URL
    var branch: String
    var statusMap: [String: GitFileStatus]  // absolute path -> status
    var uncommittedCount: Int
}

/// Manages git status for a directory tree, shelling out to the `git` CLI.
///
/// Design decision: shell out to `git` rather than use libgit2 because:
///   1. No external dependency needed
///   2. git is always available on macOS dev machines
///   3. Simpler to maintain
///   4. git status output is well-defined and stable
final class GitStatusManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var repositories: [URL: GitRepository] = [:]
    @Published private(set) var isRefreshing = false

    // MARK: - Private

    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5.0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    static let shared = GitStatusManager()

    init() {}

    // MARK: - Public API

    /// Refresh git status for `rootURL` (and detect any nested git repos within).
    /// Safe to call from any thread; UI updates are dispatched to main.
    func refresh(for rootURL: URL) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performRefresh(for: rootURL)
        }
    }

    /// Start auto-refresh timer anchored on `rootURL`
    func startAutoRefresh(for rootURL: URL) {
        stopAutoRefresh()
        refresh(for: rootURL)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: self.refreshInterval, repeats: true) { [weak self] _ in
                self?.refresh(for: rootURL)
            }
        }
    }

    /// Stop the auto-refresh timer
    func stopAutoRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshTimer?.invalidate()
            self?.refreshTimer = nil
        }
    }

    /// Returns the git status for the file at `absolutePath`, or `.clean` if
    /// the file is not in a tracked repository.
    func status(for absolutePath: String) -> GitFileStatus {
        for repo in repositories.values {
            if let s = repo.statusMap[absolutePath] {
                return s
            }
            // For directories: return .modified if any child has a non-clean status
            if absolutePath.hasPrefix(repo.rootURL.path) {
                let prefix = absolutePath.hasSuffix("/") ? absolutePath : absolutePath + "/"
                let hasModifiedChild = repo.statusMap.keys.contains { $0.hasPrefix(prefix) }
                if hasModifiedChild { return .modified }
            }
        }
        return .clean
    }

    /// Returns the GitRepository whose root best contains `url`, or nil.
    func repository(containing url: URL) -> GitRepository? {
        var best: GitRepository? = nil
        for repo in repositories.values {
            if url.path.hasPrefix(repo.rootURL.path) {
                if best == nil || repo.rootURL.path.count > best!.rootURL.path.count {
                    best = repo
                }
            }
        }
        return best
    }

    // MARK: - Private implementation

    private func performRefresh(for rootURL: URL) {
        DispatchQueue.main.async { self.isRefreshing = true }

        var allRepos: [URL: GitRepository] = [:]

        // Primary repo containing rootURL
        if let primary = buildRepository(for: rootURL) {
            allRepos[primary.rootURL] = primary
        }

        // Detect nested repos up to 2 levels deep
        let nestedRoots = findNestedGitRoots(under: rootURL, maxDepth: 2)
        for nestedRoot in nestedRoots {
            if let nested = buildRepository(for: nestedRoot) {
                allRepos[nested.rootURL] = nested
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.repositories = allRepos
            self?.isRefreshing = false
        }
    }

    /// Build a GitRepository for the git repo that contains `url`.
    private func buildRepository(for url: URL) -> GitRepository? {
        guard let gitRoot = findGitRoot(from: url) else { return nil }

        let branch = currentBranch(at: gitRoot)
        let statusMap = parseStatus(at: gitRoot)
        let uncommittedCount = statusMap.values.filter { $0 != .clean && $0 != .ignored }.count

        return GitRepository(
            rootURL: gitRoot,
            branch: branch,
            statusMap: statusMap,
            uncommittedCount: uncommittedCount
        )
    }

    /// Walk up the directory tree to find the `.git` directory
    private func findGitRoot(from url: URL) -> URL? {
        var current = url.hasDirectoryPath ? url : url.deletingLastPathComponent()

        while current.path != "/" {
            let gitDir = current.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir.path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        let gitDir = current.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitDir.path) {
            return current
        }
        return nil
    }

    /// Find subdirectories that are themselves git repo roots
    private func findNestedGitRoots(under url: URL, maxDepth: Int) -> [URL] {
        guard maxDepth > 0 else { return [] }

        var results: [URL] = []
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }

            let gitDir = item.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir.path) {
                results.append(item)
            } else {
                results += findNestedGitRoots(under: item, maxDepth: maxDepth - 1)
            }
        }
        return results
    }

    /// Get current branch name via `git rev-parse --abbrev-ref HEAD`
    private func currentBranch(at repoRoot: URL) -> String {
        let output = runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: repoRoot)
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if branch == "HEAD" {
            let hash = runGit(["rev-parse", "--short", "HEAD"], at: repoRoot)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return hash.isEmpty ? "HEAD" : "(\(hash))"
        }
        return branch.isEmpty ? "unknown" : branch
    }

    /// Parse `git status --porcelain -z` output into an absolute-path -> status map
    private func parseStatus(at repoRoot: URL) -> [String: GitFileStatus] {
        let output = runGit(["status", "--porcelain", "-z"], at: repoRoot)
        var map: [String: GitFileStatus] = [:]

        let records = output.components(separatedBy: "\0")
        for record in records {
            guard record.count >= 3 else { continue }

            let x = record[record.startIndex]
            let y = record[record.index(record.startIndex, offsetBy: 1)]
            let path = String(record.dropFirst(3))

            if path.isEmpty { continue }

            let absolutePath = repoRoot.appendingPathComponent(path).path
            let status = resolveStatus(x: x, y: y)
            map[absolutePath] = status
        }

        return map
    }

    /// Map XY porcelain codes to GitFileStatus
    private func resolveStatus(x: Character, y: Character) -> GitFileStatus {
        if x == "?" && y == "?" { return .untracked }
        if x == "!" && y == "!" { return .ignored }
        if x == "U" || y == "U" { return .conflicted }
        if (x == "A" && y == "A") || (x == "D" && y == "D") { return .conflicted }
        if x == "A" { return .added }
        if x == "D" || y == "D" { return .deleted }
        if x == "R" || y == "R" { return .renamed }
        if x == "M" || y == "M" { return .modified }
        if x == "C" || y == "C" { return .added }
        return .clean
    }

    // MARK: - Shell helpers

    /// Run a git subcommand at the given directory and return stdout.
    @discardableResult
    func runGit(_ args: [String], at directory: URL) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory

        var env = ProcessInfo.processInfo.environment
        env["GIT_OPTIONAL_LOCKS"] = "0"
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["LANG"] = "en_US.UTF-8"
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
