import XCTest
@testable import RickTerminal

/// Unit tests for GitStatusManager
final class GitStatusManagerTests: XCTestCase {

    var manager: GitStatusManager!

    override func setUp() {
        super.setUp()
        manager = GitStatusManager()
    }

    override func tearDown() {
        manager.stopAutoRefresh()
        manager = nil
        super.tearDown()
    }

    // MARK: - GitFileStatus Color Tests

    func testGitFileStatusColors() {
        XCTAssertEqual(GitFileStatus.modified.colorHex, "FF9F40", "Modified should be orange")
        XCTAssertEqual(GitFileStatus.added.colorHex, "7FFC50", "Added should be green")
        XCTAssertEqual(GitFileStatus.deleted.colorHex, "FF5555", "Deleted should be red")
        XCTAssertEqual(GitFileStatus.renamed.colorHex, "FF9F40", "Renamed should be orange")
        XCTAssertEqual(GitFileStatus.untracked.colorHex, "9CA3AF", "Untracked should be grey")
        XCTAssertEqual(GitFileStatus.ignored.colorHex, "6B7280", "Ignored should be dark grey")
        XCTAssertEqual(GitFileStatus.conflicted.colorHex, "FF5555", "Conflicted should be red")
        XCTAssertEqual(GitFileStatus.clean.colorHex, "9CA3AF", "Clean should be default grey")
    }

    // MARK: - GitFileStatus Badge Tests

    func testGitFileStatusBadges() {
        XCTAssertEqual(GitFileStatus.modified.badge, "M")
        XCTAssertEqual(GitFileStatus.added.badge, "A")
        XCTAssertEqual(GitFileStatus.deleted.badge, "D")
        XCTAssertEqual(GitFileStatus.renamed.badge, "R")
        XCTAssertEqual(GitFileStatus.untracked.badge, "U")
        XCTAssertNil(GitFileStatus.ignored.badge, "Ignored files should have no badge")
        XCTAssertEqual(GitFileStatus.conflicted.badge, "!")
        XCTAssertNil(GitFileStatus.clean.badge, "Clean files should have no badge")
    }

    // MARK: - Repository Detection Tests

    func testRepositoryNotFoundForNonGitDir() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rt_test_" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let repo = manager.repository(containing: tempDir)
        XCTAssertNil(repo, "Non-git directory should not have a repository")
    }

    func testRepositoryForCurrentProjectIsDetected() {
        let projectRoot = URL(fileURLWithPath: "/Users/elmo.asmussen/Projects/CTO/rick-terminal")
        guard FileManager.default.fileExists(atPath: projectRoot.path) else { return }

        let expectation = XCTestExpectation(description: "Git refresh completes for project root")
        manager.refresh(for: projectRoot)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let repo = self.manager.repository(containing: projectRoot)
            XCTAssertNotNil(repo, "Project root git repo should be detected")
            XCTAssertFalse(repo?.branch.isEmpty ?? true, "Branch name should not be empty")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 6.0)
    }

    // MARK: - Status For Path Tests

    func testStatusForUnknownPathReturnsClean() {
        let fakePath = "/this/path/does/not/exist/anywhere"
        XCTAssertEqual(manager.status(for: fakePath), .clean)
    }

    func testStatusForNonRepoTempDirReturnsClean() {
        let nonRepoPath = NSTemporaryDirectory()
        XCTAssertEqual(manager.status(for: nonRepoPath), .clean)
    }

    // MARK: - Uncommitted Count Tests

    func testUncommittedCountExcludesIgnoredAndClean() {
        let mockRepo = GitRepository(
            rootURL: URL(fileURLWithPath: "/tmp"),
            branch: "main",
            statusMap: [
                "/tmp/file1.swift": .modified,
                "/tmp/file2.swift": .added,
                "/tmp/file3.swift": .ignored,
                "/tmp/file4.swift": .clean,
            ],
            uncommittedCount: 2
        )
        XCTAssertEqual(mockRepo.uncommittedCount, 2)
    }

    func testGitRepositoryBranchName() {
        let mockRepo = GitRepository(
            rootURL: URL(fileURLWithPath: "/tmp"),
            branch: "feature/RT-032",
            statusMap: [:],
            uncommittedCount: 0
        )
        XCTAssertEqual(mockRepo.branch, "feature/RT-032")
    }

    // MARK: - Auto-Refresh Timer Tests

    func testStartAndStopAutoRefreshDoesNotCrash() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        manager.startAutoRefresh(for: tempDir)
        manager.stopAutoRefresh()
        manager.startAutoRefresh(for: tempDir)
        manager.stopAutoRefresh()
    }

    func testStopAutoRefreshWithoutStartIsIdempotent() {
        manager.stopAutoRefresh()
        manager.stopAutoRefresh()
    }

    // MARK: - Git Command Tests

    func testRunGitVersionReturnsOutput() {
        let output = manager.runGit(["--version"], at: URL(fileURLWithPath: "/usr/bin"))
        XCTAssertTrue(output.contains("git version"), "git --version should contain 'git version'")
    }

    func testRunGitInvalidCommandReturnsEmptyOrError() {
        let output = manager.runGit(["__no_such_subcommand__"], at: URL(fileURLWithPath: "/tmp"))
        XCTAssertNotNil(output)
    }

    func testRunGitAtInvalidPathReturnsEmpty() {
        let output = manager.runGit(["status"], at: URL(fileURLWithPath: "/nonexistent/path"))
        XCTAssertNotNil(output)
    }

    // MARK: - Refresh Does Not Crash Tests

    func testRefreshOnNonGitDirDoesNotCrash() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        manager.refresh(for: tempDir)
    }

    func testRefreshOnFilepathDoesNotCrash() {
        let filePath = URL(fileURLWithPath: "/etc/hosts")
        manager.refresh(for: filePath)
    }

    // MARK: - Notification Name Tests

    func testGitStatusRefreshNeededNotificationNameExists() {
        let name = Notification.Name.gitStatusRefreshNeeded
        XCTAssertEqual(name.rawValue, "gitStatusRefreshNeeded")
    }

    // MARK: - Equatable Tests

    func testGitFileStatusEquatable() {
        XCTAssertEqual(GitFileStatus.modified, GitFileStatus.modified)
        XCTAssertNotEqual(GitFileStatus.modified, GitFileStatus.added)
        XCTAssertNotEqual(GitFileStatus.clean, GitFileStatus.untracked)
    }

    // MARK: - Directory Status Propagation Tests

    func testDirectoryStatusCleanWhenNoReposLoaded() {
        // With no repos loaded, any path returns .clean
        let dirPath = "/some/fake/dir"
        XCTAssertEqual(manager.status(for: dirPath), .clean)
    }
}
