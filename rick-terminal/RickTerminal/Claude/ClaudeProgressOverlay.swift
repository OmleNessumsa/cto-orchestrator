import SwiftUI
import Combine

/// Overlay showing Claude's current tool activity
/// Displays real-time progress when Claude is using tools
struct ClaudeProgressOverlay: View {

    @ObservedObject var progressManager: ClaudeProgressManager

    /// Animation state for the progress indicator
    @State private var isAnimating = false

    /// Whether to show the overlay
    var isVisible: Bool {
        progressManager.currentEvent != nil || progressManager.isProcessing
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Animated progress indicator
                progressIndicator

                // Tool info
                VStack(alignment: .leading, spacing: 2) {
                    if let event = progressManager.currentEvent {
                        // Tool name and icon
                        HStack(spacing: 6) {
                            Image(systemName: event.toolType.iconName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(toolColor(for: event))

                            Text(event.toolType.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtTextPrimary)
                        }

                        // Tool description
                        Text(event.toolType.shortDescription)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.rtTextSecondary)
                            .lineLimit(1)
                    } else if progressManager.isProcessing {
                        // Generic processing indicator
                        HStack(spacing: 6) {
                            Image(systemName: "brain")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rtAccentPurple)

                            Text("Processing")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.rtTextPrimary)
                        }

                        Text("Claude is thinking...")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.rtTextSecondary)
                    }
                }

                Spacer()

                // Recent tools indicator
                if progressManager.recentToolCount > 1 {
                    HStack(spacing: 4) {
                        ForEach(progressManager.recentTools.prefix(5), id: \.id) { event in
                            Circle()
                                .fill(statusColor(for: event.status))
                                .frame(width: 6, height: 6)
                        }

                        if progressManager.recentToolCount > 5 {
                            Text("+\(progressManager.recentToolCount - 5)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.rtTextSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(overlayBackground)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(16)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        }
    }

    // MARK: - Components

    private var progressIndicator: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.rtBackgroundSecondary, lineWidth: 2)
                .frame(width: 32, height: 32)

            // Animated progress ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )

            // Center icon
            if let event = progressManager.currentEvent {
                Image(systemName: event.toolType.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(progressColor)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.rtAccentPurple)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var overlayBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.rtBackgroundLight.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(progressColor.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private var progressColor: Color {
        if let event = progressManager.currentEvent {
            return toolColor(for: event)
        }
        return .rtAccentPurple
    }

    private func toolColor(for event: ClaudeToolEvent) -> Color {
        switch event.toolType.category {
        case .file:
            return .rtAccentBlue
        case .command:
            return .rtAccentGreen
        case .search:
            return .rtAccentPurple
        case .network:
            return .rtAccentOrange
        case .agent:
            return .rtAccentPurple
        case .interaction:
            return .rtAccentGreen
        case .other:
            return .rtTextSecondary
        }
    }

    private func statusColor(for status: ClaudeToolStatus) -> Color {
        switch status {
        case .started, .executing:
            return .rtAccentBlue
        case .completed:
            return .rtAccentGreen
        case .failed:
            return .rtAccentOrange
        case .cancelled:
            return .rtTextSecondary
        }
    }
}

// MARK: - Claude Progress Manager

/// Manages Claude tool progress state for the overlay
class ClaudeProgressManager: ObservableObject {

    @Published private(set) var currentEvent: ClaudeToolEvent?
    @Published private(set) var recentTools: [ClaudeToolEvent] = []
    @Published private(set) var isProcessing: Bool = false

    /// Maximum number of recent tools to track
    private let maxRecentTools = 10

    /// Timeout for clearing current event
    private var clearTimer: Timer?

    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()

    var recentToolCount: Int {
        recentTools.count
    }

    init() {}

    /// Subscribe to a Claude output parser
    func subscribe(to parser: ClaudeOutputParser) {
        // Unsubscribe from previous
        cancellables.removeAll()

        parser.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Unsubscribe from parser
    func unsubscribe() {
        cancellables.removeAll()
        clearTimer?.invalidate()
        clearTimer = nil

        currentEvent = nil
        isProcessing = false
    }

    /// Manually set processing state
    func setProcessing(_ processing: Bool) {
        isProcessing = processing

        if !processing {
            scheduleClear()
        }
    }

    // MARK: - Private

    private func handleEvent(_ event: ClaudeToolEvent) {
        clearTimer?.invalidate()

        switch event.status {
        case .started, .executing:
            currentEvent = event
            isProcessing = true

        case .completed, .failed, .cancelled:
            // Add to recent tools
            addToRecent(event)

            // Clear after a short delay
            scheduleClear()
        }
    }

    private func addToRecent(_ event: ClaudeToolEvent) {
        // Update existing or add new
        if let index = recentTools.firstIndex(where: { $0.id == event.id }) {
            recentTools[index] = event
        } else {
            recentTools.insert(event, at: 0)

            // Trim to max
            if recentTools.count > maxRecentTools {
                recentTools = Array(recentTools.prefix(maxRecentTools))
            }
        }
    }

    private func scheduleClear() {
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.currentEvent = nil
            self?.isProcessing = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ClaudeProgressOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.rtBackgroundDark
                .ignoresSafeArea()

            VStack {
                Spacer()

                ClaudeProgressOverlay(progressManager: {
                    let manager = ClaudeProgressManager()
                    // Simulate an event
                    return manager
                }())

                Spacer()
            }
        }
        .frame(width: 600, height: 400)
    }
}
#endif
