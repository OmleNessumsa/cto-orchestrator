import SwiftUI

// MARK: - Rick Terminal Icon System

/// Centralized SF Symbols icon management for Rick Terminal
/// NO EMOJIS - Professional application icons only
enum RTIcon: String {
    // MARK: - Navigation & UI Chrome

    /// Sidebar toggle - left side
    case sidebarLeft = "sidebar.left"
    case sidebarLeftFilled = "sidebar.left.fill"

    /// Sidebar toggle - right side
    case sidebarRight = "sidebar.right"
    case sidebarRightFilled = "sidebar.right.fill"

    /// Chevron indicators
    case chevronRight = "chevron.right"
    case chevronDown = "chevron.down"

    /// Close button
    case close = "xmark"
    case closeCircle = "xmark.circle"
    case closeCircleFilled = "xmark.circle.fill"

    /// Add/Create actions
    case add = "plus.circle"
    case addFilled = "plus.circle.fill"

    // MARK: - Application Modes

    /// Terminal mode
    case terminal = "terminal"
    case terminalFilled = "terminal.fill"

    /// Editor/Document mode
    case document = "doc.text"
    case documentFilled = "doc.text.fill"

    /// Settings/Configuration
    case settings = "gearshape"
    case settingsFilled = "gearshape.fill"
    case settingsDouble = "gearshape.2.fill"

    // MARK: - File Operations

    /// Generic file
    case file = "doc"
    case fileFilled = "doc.fill"

    /// Text file
    case textFile = "doc.plaintext"
    case textFileFilled = "doc.plaintext.fill"

    /// Rich text
    case richText = "doc.richtext"

    /// Code/Programming
    case code = "curlybraces"
    case swift = "swift"

    /// Create/Write file
    case fileCreate = "doc.badge.plus"

    /// Edit file
    case edit = "pencil"
    case editCircle = "pencil.circle"

    // MARK: - Folder/Directory

    /// Standard folder
    case folder = "folder"
    case folderFilled = "folder.fill"
    case folderMinusFilled = "folder.fill.badge.minus"

    /// Folder actions
    case folderCreate = "folder.badge.plus"
    case folderQuestion = "folder.badge.questionmark"

    // MARK: - Git/Version Control

    /// Git branch
    case gitBranch = "arrow.triangle.branch"

    /// Build/Hammer
    case build = "hammer.fill"

    // MARK: - Search

    /// Standard search
    case search = "magnifyingglass"
    case searchCircle = "magnifyingglass.circle"

    // MARK: - Status Indicators

    /// Success/Checkmark
    case check = "checkmark"
    case checkCircle = "checkmark.circle"
    case checkCircleFilled = "checkmark.circle.fill"

    /// Warning/Alert
    case warning = "exclamationmark.triangle"
    case warningFilled = "exclamationmark.triangle.fill"

    /// Error/X mark
    case error = "xmark.octagon"
    case errorFilled = "xmark.octagon.fill"

    /// Info/Question
    case info = "info.circle"
    case infoFilled = "info.circle.fill"
    case question = "questionmark.circle"
    case questionSquare = "questionmark.square"

    // MARK: - Priority Indicators

    /// Low priority
    case priorityLow = "arrow.down"

    /// Medium priority
    case priorityMedium = "minus"

    /// High priority
    case priorityHigh = "arrow.up"

    /// Critical priority (uses 2-exclamation variant to be unique)
    case priorityCritical = "exclamationmark.2"

    // MARK: - Status/Workflow

    /// Backlog/Inbox
    case backlog = "tray"
    case inbox = "tray.fill"

    /// In progress
    case inProgress = "arrow.right.circle"
    case inProgressFilled = "arrow.right.circle.fill"

    /// Review/Eye
    case review = "eye"
    case reviewFilled = "eye.fill"

    /// Visibility toggle (aliases - use review/reviewFilled)
    case hidden = "eye.slash.fill"

    /// Done/Complete (aliases - use checkCircle/checkCircleFilled)

    /// Blocked (use error for same icon)

    // MARK: - Card Sources

    /// Manual/Hand created
    case manual = "hand.tap"

    /// AI/Claude generated
    case ai = "sparkles"

    /// Ticket reference
    case ticket = "ticket"
    case ticketFilled = "ticket.fill"

    /// Sub-agent/Person
    case subAgent = "person.crop.circle.badge.clock"

    // MARK: - Agent Roles

    /// Architect
    case architect = "building.columns"

    /// Backend/Server
    case backend = "server.rack"

    /// Frontend/Window
    case frontend = "macwindow"

    /// Explorer (use search for same icon - or scope variant)
    case explorer = "doc.text.magnifyingglass"

    /// Planner/Map
    case planner = "map"

    /// General purpose
    case person = "person.crop.circle"
    case personFilled = "person.crop.circle.fill"

    /// Team/Multiple people
    case team = "person.3.fill"

    /// Book/Guide
    case book = "book"
    case bookFilled = "book.fill"

    // MARK: - Agent Status

    /// Working/Processing (use gear instead of 2-gear to be unique)
    case working = "gear"

    /// Idle/Paused
    case idle = "pause.circle"
    case idleFilled = "pause.circle.fill"

    /// Playing/Running
    case play = "play.circle"
    case playFilled = "play.circle.fill"

    /// Stop
    case stop = "stop.circle"
    case stopFilled = "stop.circle.fill"

    // MARK: - Time/Schedule

    /// Clock
    case clock = "clock"
    case clockFilled = "clock.fill"

    /// Calendar
    case calendar = "calendar"
    case calendarFilled = "calendar.fill"

    // MARK: - Tool Types

    /// Bash/Terminal command (use rectangle with chevron for CLI distinction)
    case bash = "apple.terminal"

    /// Globe/Web
    case web = "globe"

    /// Network
    case network = "network"

    /// Checklist/Todo
    case checklist = "checklist"

    /// Magic wand (skills)
    case magic = "wand.and.stars"

    /// Notebook (use closed book variant for distinction)
    case notebook = "book.closed"

    // MARK: - Media Types

    /// Photo/Image
    case photo = "photo"
    case photoFilled = "photo.fill"

    /// Film/Video
    case film = "film"
    case filmFilled = "film.fill"

    /// Music/Audio
    case music = "music.note"

    /// Archive/Zip
    case archive = "doc.zipper"

    // MARK: - Actions

    /// Refresh/Reload
    case refresh = "arrow.clockwise"
    case refreshCircle = "arrow.clockwise.circle"

    /// Sync/Update
    case sync = "arrow.triangle.2.circlepath"

    /// Expand
    case expand = "rectangle.expand.vertical"

    /// Number/Counter
    case number = "number.circle"

    /// Assignee/Person with circle
    case assignee = "person.circle.fill"

    // MARK: - Helper Methods

    /// Get the Image view for this icon
    var image: Image {
        Image(systemName: self.rawValue)
    }

    /// Get the Image view with specified font size
    func image(size: CGFloat) -> some View {
        Image(systemName: self.rawValue)
            .font(.system(size: size))
    }

    /// Get the Image view with specified font and color
    func image(size: CGFloat, color: Color) -> some View {
        Image(systemName: self.rawValue)
            .font(.system(size: size))
            .foregroundColor(color)
    }

    /// Get the raw SF Symbol name
    var symbolName: String {
        self.rawValue
    }
}

// MARK: - View Extension

extension View {
    /// Apply an RTIcon as a label
    func rtIcon(_ icon: RTIcon) -> some View {
        self.modifier(RTIconModifier(icon: icon))
    }
}

// MARK: - Icon Modifier

private struct RTIconModifier: ViewModifier {
    let icon: RTIcon

    func body(content: Content) -> some View {
        Label {
            content
        } icon: {
            icon.image
        }
    }
}

// MARK: - Backward Compatibility Helpers

extension RTIcon {
    /// Map from old string-based icon names to RTIcon enum
    static func from(systemName: String) -> RTIcon? {
        // Try direct match first
        if let icon = RTIcon(rawValue: systemName) {
            return icon
        }

        // Handle common variations
        switch systemName {
        case "sidebar.left": return .sidebarLeft
        case "sidebar.left.fill": return .sidebarLeftFilled
        case "sidebar.right": return .sidebarRight
        case "sidebar.right.fill": return .sidebarRightFilled
        case "terminal": return .terminal
        case "doc.text": return .document
        case "plus.circle": return .add
        case "xmark": return .close
        case "xmark.circle.fill": return .closeCircleFilled
        case "exclamationmark.triangle.fill": return .warningFilled
        case "checkmark.circle.fill": return .checkCircleFilled
        case "magnifyingglass": return .search
        case "eye.fill": return .reviewFilled
        case "eye.slash.fill": return .hidden
        case "arrow.clockwise": return .refresh
        case "folder.badge.plus": return .folderCreate
        case "folder.badge.questionmark": return .folderQuestion
        case "chevron.down": return .chevronDown
        case "chevron.right": return .chevronRight
        case "folder.fill": return .folderFilled
        case "folder.fill.badge.minus": return .folderMinusFilled
        case "tray": return .backlog
        case "sparkles": return .ai
        case "person.circle.fill": return .assignee
        case "calendar": return .calendar
        case "number.circle": return .number
        case "arrow.triangle.2.circlepath": return .sync
        case "hand.tap": return .manual
        case "ticket": return .ticket
        case "person.crop.circle.badge.clock": return .subAgent
        case "building.columns": return .architect
        case "server.rack": return .backend
        case "macwindow": return .frontend
        case "map": return .planner
        case "person.crop.circle": return .person
        case "gearshape": return .settings
        case "book": return .book
        case "questionmark.circle": return .question
        case "gearshape.2.fill": return .working
        case "pause.circle": return .idle
        case "clock": return .clock
        case "pencil": return .edit
        case "doc.badge.plus": return .fileCreate
        case "globe": return .web
        case "magnifyingglass.circle": return .searchCircle
        case "checklist": return .checklist
        case "questionmark.square": return .questionSquare
        case "wand.and.stars": return .magic
        case "person.3.fill": return .team
        case "rectangle.expand.vertical": return .expand
        case "arrow.right.circle": return .inProgress
        case "eye": return .review
        case "xmark.octagon": return .error
        case "arrow.down": return .priorityLow
        case "minus": return .priorityMedium
        case "arrow.up": return .priorityHigh
        case "exclamationmark.triangle": return .priorityCritical
        default: return nil
        }
    }
}
