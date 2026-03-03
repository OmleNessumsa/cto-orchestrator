import Foundation

/// Example: How to integrate Claude CLI path detection in your code
///
/// This demonstrates various ways to use the ClaudePathDetector
/// and TerminalSettings to work with Claude CLI.

// MARK: - Basic Usage

func example1_BasicUsage() {
    print("Example 1: Basic Usage")
    print("======================\n")

    // Get the configured Claude CLI path
    if let claudePath = TerminalSettings.shared.getClaudeCliPath() {
        print("✓ Claude CLI configured at: \(claudePath)")

        // You can now use this path to execute Claude
        // Example: Process().executableURL = URL(fileURLWithPath: claudePath)
    } else {
        print("✗ Claude CLI not configured")
        print("  User should open Settings (Cmd+,) to configure it")
    }
}

// MARK: - Executing Claude with Error Handling

func example2_ExecuteClaudeCommand() {
    print("\nExample 2: Execute Claude Command")
    print("==================================\n")

    guard let claudePath = TerminalSettings.shared.getClaudeCliPath() else {
        print("Error: Claude CLI not configured")
        return
    }

    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: claudePath)
    process.arguments = ["--version"]
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("Claude CLI version:\n\(output)")
        }

        if process.terminationStatus == 0 {
            print("✓ Command executed successfully")
        } else {
            print("✗ Command failed with status: \(process.terminationStatus)")
        }
    } catch {
        print("Error executing Claude: \(error)")
    }
}

// MARK: - Manual Path Configuration

func example3_ManualConfiguration() {
    print("\nExample 3: Manual Configuration")
    print("================================\n")

    let customPath = "/opt/homebrew/bin/claude"

    if TerminalSettings.shared.setClaudeCliPath(customPath) {
        print("✓ Path validated and saved: \(customPath)")
    } else {
        print("✗ Invalid path: \(customPath)")
        print("  Make sure the file exists and is executable")
    }
}

// MARK: - Checking Path Without Auto-Detection

func example4_CheckPathOnly() {
    print("\nExample 4: Check Path Without Auto-Detection")
    print("=============================================\n")

    let currentPath = TerminalSettings.shared.claudeCliPath

    if currentPath.isEmpty {
        print("No path configured yet")
    } else {
        print("Stored path: \(currentPath)")

        // Validate it's still valid
        if ClaudePathDetector.shared.isValidClaudePath(currentPath) {
            print("✓ Path is still valid")
        } else {
            print("✗ Path is no longer valid (Claude may have been uninstalled)")
            print("  Consider re-running auto-detection")
        }
    }
}

// MARK: - Reset and Re-detect

func example5_ResetDetection() {
    print("\nExample 5: Reset and Re-detect")
    print("===============================\n")

    print("Resetting detection cache...")
    TerminalSettings.shared.resetClaudeCliDetection()

    print("Running auto-detection again...")
    if let newPath = TerminalSettings.shared.getClaudeCliPath() {
        print("✓ Detected: \(newPath)")
    } else {
        print("✗ Could not detect Claude CLI")
    }
}

// MARK: - Using in Shell Session Manager

class ClaudeIntegratedSessionManager {
    /// Example: How a session manager might use Claude CLI
    func createClaudeSession(command: String) throws {
        guard let claudePath = TerminalSettings.shared.getClaudeCliPath() else {
            throw SessionError.claudeNotConfigured
        }

        print("Starting Claude session with command: \(command)")
        print("Using Claude at: \(claudePath)")

        // Create process with Claude CLI
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [command]

        // Configure pipes, environment, etc.
        // ... your session setup code here ...
    }

    enum SessionError: Error {
        case claudeNotConfigured
    }
}

// MARK: - Reactive Observation with Combine

import Combine

class ClaudePathObserver: ObservableObject {
    /// Observe changes to Claude CLI configuration
    @Published var isConfigured: Bool = false
    @Published var currentPath: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe changes to the settings
        TerminalSettings.shared.$claudeCliPath
            .sink { [weak self] newPath in
                self?.currentPath = newPath
                self?.isConfigured = !newPath.isEmpty &&
                    ClaudePathDetector.shared.isValidClaudePath(newPath)
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct ClaudeStatusView: View {
    @ObservedObject var settings = TerminalSettings.shared

    var body: some View {
        HStack {
            if let path = settings.getClaudeCliPath() {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Claude configured")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Claude not configured")
                Button("Configure") {
                    // Open settings window
                }
            }
        }
    }
}

// MARK: - Main Example Runner

func runAllExamples() {
    example1_BasicUsage()
    example2_ExecuteClaudeCommand()
    example3_ManualConfiguration()
    example4_CheckPathOnly()
    example5_ResetDetection()

    print("\n" + String(repeating: "=", count: 50))
    print("All examples complete!")
    print(String(repeating: "=", count: 50))
}

// Uncomment to run examples:
// runAllExamples()
