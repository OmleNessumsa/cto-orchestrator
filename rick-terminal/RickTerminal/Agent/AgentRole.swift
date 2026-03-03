import SwiftUI

// MARK: - Agent Role

/// Classification of agent types based on Task tool's subagent_type
enum AgentRole: String, Codable, CaseIterable {
    case architect = "architect"
    case backend = "backend"
    case frontend = "frontend"
    case explorer = "Explore"
    case planner = "Plan"
    case generalPurpose = "general-purpose"
    case bash = "Bash"
    case statuslineSetup = "statusline-setup"
    case claudeCodeGuide = "claude-code-guide"
    case unknown = "unknown"

    // MARK: - Initialization

    /// Create role from subagent_type string
    init(from subagentType: String?) {
        guard let type = subagentType?.lowercased() else {
            self = .unknown
            return
        }

        switch type {
        case "architect", "architect-morty":
            self = .architect
        case "backend", "backend-morty":
            self = .backend
        case "frontend", "frontend-morty":
            self = .frontend
        case "explore":
            self = .explorer
        case "plan":
            self = .planner
        case "general-purpose":
            self = .generalPurpose
        case "bash":
            self = .bash
        case "statusline-setup":
            self = .statuslineSetup
        case "claude-code-guide":
            self = .claudeCodeGuide
        default:
            // Check for "morty" suffix pattern
            if type.contains("morty") {
                if type.contains("architect") {
                    self = .architect
                } else if type.contains("backend") {
                    self = .backend
                } else if type.contains("frontend") {
                    self = .frontend
                } else {
                    self = .generalPurpose
                }
            } else {
                self = .unknown
            }
        }
    }

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .architect:
            return "Architect"
        case .backend:
            return "Backend"
        case .frontend:
            return "Frontend"
        case .explorer:
            return "Explorer"
        case .planner:
            return "Planner"
        case .generalPurpose:
            return "General"
        case .bash:
            return "Command"
        case .statuslineSetup:
            return "Setup"
        case .claudeCodeGuide:
            return "Guide"
        case .unknown:
            return "Agent"
        }
    }

    /// Rick & Morty themed display name
    var mortyName: String {
        switch self {
        case .architect:
            return "Architect Morty"
        case .backend:
            return "Backend Morty"
        case .frontend:
            return "Frontend Morty"
        case .explorer:
            return "Explorer Morty"
        case .planner:
            return "Planner Morty"
        case .generalPurpose:
            return "Worker Morty"
        case .bash:
            return "Terminal Morty"
        case .statuslineSetup:
            return "Config Morty"
        case .claudeCodeGuide:
            return "Guide Morty"
        case .unknown:
            return "Morty"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .architect:
            return "building.columns"
        case .backend:
            return "server.rack"
        case .frontend:
            return "macwindow"
        case .explorer:
            return "magnifyingglass"
        case .planner:
            return "map"
        case .generalPurpose:
            return "person.crop.circle"
        case .bash:
            return "terminal"
        case .statuslineSetup:
            return "gearshape"
        case .claudeCodeGuide:
            return "book"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Role-specific accent color
    var themeColor: Color {
        switch self {
        case .architect:
            return .rtAccentPurple
        case .backend:
            return Color(hex: "2196F3")  // Blue
        case .frontend:
            return Color(hex: "FF9800")  // Orange
        case .explorer:
            return Color(hex: "00BCD4")  // Cyan
        case .planner:
            return Color(hex: "9C27B0")  // Purple
        case .generalPurpose:
            return .rtAccentGreen
        case .bash:
            return Color(hex: "607D8B")  // Blue-gray
        case .statuslineSetup:
            return Color(hex: "795548")  // Brown
        case .claudeCodeGuide:
            return Color(hex: "4CAF50")  // Green
        case .unknown:
            return .rtMuted
        }
    }

    /// Background color with reduced opacity for column
    var backgroundColor: Color {
        themeColor.opacity(0.15)
    }

    /// Border color for column
    var borderColor: Color {
        themeColor.opacity(0.5)
    }
}

// MARK: - Hashable

extension AgentRole: Hashable {}
