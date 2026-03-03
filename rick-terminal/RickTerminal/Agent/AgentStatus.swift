import SwiftUI

// MARK: - Agent Status

/// Lifecycle state of an agent column
enum AgentStatus: String, Codable, CaseIterable {
    /// Just created, appearing animation in progress
    case spawning

    /// Actively executing tools
    case working

    /// Waiting between actions
    case idle

    /// Completed successfully
    case done

    /// Failed with error
    case error

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .spawning:
            return "Spawning"
        case .working:
            return "Working"
        case .idle:
            return "Idle"
        case .done:
            return "Done"
        case .error:
            return "Error"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .spawning:
            return "sparkles"
        case .working:
            return "gearshape.2.fill"
        case .idle:
            return "pause.circle"
        case .done:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Status-specific color
    var color: Color {
        switch self {
        case .spawning:
            return Color(hex: "00BCD4")  // Cyan
        case .working:
            return .rtAccentGreen
        case .idle:
            return .rtMuted
        case .done:
            return Color(hex: "4CAF50")  // Green
        case .error:
            return Color(hex: "F44336")  // Red
        }
    }

    /// Whether status represents active work
    var isActive: Bool {
        switch self {
        case .spawning, .working:
            return true
        case .idle, .done, .error:
            return false
        }
    }

    /// Whether status is terminal (agent finished)
    var isTerminal: Bool {
        switch self {
        case .done, .error:
            return true
        case .spawning, .working, .idle:
            return false
        }
    }

    /// Whether status should show pulsing animation
    var shouldPulse: Bool {
        switch self {
        case .spawning, .working:
            return true
        case .idle, .done, .error:
            return false
        }
    }
}

// MARK: - Hashable

extension AgentStatus: Hashable {}
