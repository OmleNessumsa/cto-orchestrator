import Foundation

/// Debug helpers for testing error handling system
/// These functions allow testing various error scenarios in development
#if DEBUG
class ErrorHandlingTests {
    static let shared = ErrorHandlingTests()

    private init() {}

    // MARK: - Test Helpers

    /// Test all Claude CLI errors
    func testClaudeErrors() {
        print("\n=== Testing Claude CLI Errors ===")

        ErrorManager.shared.handle(.claudeNotFound)
        sleep(1)

        ErrorManager.shared.handle(.claudeNotConfigured)
        sleep(1)

        ErrorManager.shared.handle(.claudeInvalidPath("/invalid/path"))
        sleep(1)

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        ErrorManager.shared.handle(.claudeLaunchFailed(testError))
    }

    /// Test file operation errors
    func testFileErrors() {
        print("\n=== Testing File Operation Errors ===")

        ErrorManager.shared.handle(.fileNotFound("/test/missing.txt"))
        sleep(1)

        ErrorManager.shared.handle(.filePermissionDenied("/System/Library/test.txt"))
        sleep(1)

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        ErrorManager.shared.handle(.fileReadFailed("/test/file.txt", testError))
    }

    /// Test git errors
    func testGitErrors() {
        print("\n=== Testing Git Errors ===")

        ErrorManager.shared.handle(.gitNotInstalled)
        sleep(1)

        ErrorManager.shared.handle(.gitNotRepository)
        sleep(1)

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        ErrorManager.shared.handle(.gitCommandFailed("git pull origin main", testError))
    }

    /// Test session errors
    func testSessionErrors() {
        print("\n=== Testing Session Errors ===")

        ErrorManager.shared.handle(.sessionNotFound)
        sleep(1)

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        ErrorManager.shared.handle(.sessionCreationFailed(testError))
        sleep(1)

        ErrorManager.shared.handle(.ptyCreationFailed)
    }

    /// Test network errors
    func testNetworkErrors() {
        print("\n=== Testing Network Errors ===")

        ErrorManager.shared.handle(.networkUnavailable)
        sleep(1)

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        ErrorManager.shared.handle(.apiRequestFailed(testError))
        sleep(1)

        ErrorManager.shared.handle(.timeoutError)
    }

    /// Test error logging
    func testErrorLogging() {
        print("\n=== Testing Error Logging ===")

        // Log several errors without presenting to user
        for i in 1...5 {
            ErrorManager.shared.handle(
                .fileNotFound("/test/file\(i).txt"),
                additionalInfo: ["testNumber": String(i)],
                presentToUser: false
            )
        }

        // Print recent errors
        let recentLog = ErrorManager.shared.getRecentErrorLog(limit: 5)
        print("Recent errors log:\n\(recentLog)")

        // Print log file path
        print("Log file: \(ErrorManager.shared.getLogFilePath())")
    }

    /// Test error severity levels
    func testSeverityLevels() {
        print("\n=== Testing Severity Levels ===")

        // Info
        ErrorManager.shared.handle(.operationCancelled)
        print("Info severity: \(RTError.operationCancelled.severity)")

        // Warning
        ErrorManager.shared.handle(.claudeNotConfigured)
        print("Warning severity: \(RTError.claudeNotConfigured.severity)")

        // Error
        ErrorManager.shared.handle(.fileNotFound("/test"))
        print("Error severity: \(RTError.fileNotFound("/test").severity)")
    }

    /// Test file operations helper
    func testFileOperationsHelper() {
        print("\n=== Testing FileOperationsHelper ===")

        let helper = FileOperationsHelper.shared

        // Test reading non-existent file
        let readResult = helper.readFile(at: "/nonexistent/file.txt")
        switch readResult {
        case .success:
            print("❌ Should have failed")
        case .failure(let error):
            print("✅ Read error handled: \(error.userMessage)")
        }

        // Test writing to protected location
        let writeResult = helper.writeFile(
            content: "test",
            to: "/System/Library/test.txt",
            createDirectories: false
        )
        switch writeResult {
        case .success:
            print("❌ Should have failed")
        case .failure(let error):
            print("✅ Write error handled: \(error.userMessage)")
        }

        // Test path helpers
        print("Home directory: \(helper.homeDirectory())")
        print("Current directory: \(helper.currentDirectory())")
        print("Expanded path: \(helper.expandPath("~/test"))")
    }

    /// Run all tests
    func runAllTests() {
        print("\n" + String(repeating: "=", count: 50))
        print("ERROR HANDLING SYSTEM TESTS")
        print(String(repeating: "=", count: 50))

        testClaudeErrors()
        testFileErrors()
        testGitErrors()
        testSessionErrors()
        testNetworkErrors()
        testErrorLogging()
        testSeverityLevels()
        testFileOperationsHelper()

        print("\n" + String(repeating: "=", count: 50))
        print("TESTS COMPLETED")
        print(String(repeating: "=", count: 50) + "\n")
    }

    /// Quick smoke test
    func smokeTest() {
        print("\n🧪 Running error handling smoke test...")

        // Test one error from each category
        ErrorManager.shared.handle(.claudeNotFound, presentToUser: false)
        ErrorManager.shared.handle(.fileNotFound("/test"), presentToUser: false)
        ErrorManager.shared.handle(.gitNotInstalled, presentToUser: false)
        ErrorManager.shared.handle(.sessionNotFound, presentToUser: false)
        ErrorManager.shared.handle(.networkUnavailable, presentToUser: false)

        // Verify logging
        let recentErrors = ErrorManager.shared.recentErrors
        if recentErrors.count >= 5 {
            print("✅ Error logging working - \(recentErrors.count) errors recorded")
        } else {
            print("❌ Error logging failed - only \(recentErrors.count) errors recorded")
        }

        // Verify log file
        let logPath = ErrorManager.shared.getLogFilePath()
        if FileManager.default.fileExists(atPath: logPath) {
            print("✅ Log file created at: \(logPath)")
        } else {
            print("❌ Log file not found")
        }

        print("🧪 Smoke test complete\n")
    }
}
#endif
