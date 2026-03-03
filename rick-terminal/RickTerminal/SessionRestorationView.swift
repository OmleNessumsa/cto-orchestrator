import SwiftUI

/// View for restoring previous sessions on app launch
struct SessionRestorationView: View {
    let sessions: [PersistedSessionState]
    let onRestore: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var selectedSessionId: UUID?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundColor(.rtAccentGreen)

                Text("Restore Previous Session")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.rtTextPrimary)

                Text("You have \(sessions.count) saved session\(sessions.count == 1 ? "" : "s")")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.rtTextSecondary)
            }
            .padding(.top, 20)

            // Session list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sessions) { session in
                        SessionRow(
                            session: session,
                            isSelected: selectedSessionId == session.id,
                            onSelect: { selectedSessionId = session.id }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 300)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Start Fresh")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.rtBackgroundLight)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let sessionId = selectedSessionId {
                        onRestore(sessionId)
                    }
                }) {
                    Text("Restore Session")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.rtBackgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedSessionId != nil ? Color.rtAccentGreen : Color.rtTextDisabled)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(selectedSessionId == nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 500)
        .background(Color.rtBackgroundDark)
        .cornerRadius(12)
        .onAppear {
            // Pre-select the most recent session
            selectedSessionId = sessions.first?.id
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: PersistedSessionState
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.rtAccentGreen : Color.rtBorderSubtle)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    // Working directory
                    Text(session.workingDirectory)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.rtTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Metadata
                    HStack(spacing: 12) {
                        Label(session.shellType, systemImage: "terminal")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.rtTextSecondary)

                        Label(timeAgo(from: session.lastAccessedAt), systemImage: "clock")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.rtTextSecondary)
                    }
                }

                Spacer()

                // Session ID preview
                Text(session.id.uuidString.prefix(8))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.rtTextDisabled)
            }
            .padding(12)
            .background(isSelected ? Color.rtAccentGreen.opacity(0.1) : Color.rtBackgroundLight)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.rtAccentGreen : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let seconds = Int(interval)

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = seconds / 86400
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Session History View

/// View for browsing and managing saved sessions
struct SessionHistoryView: View {
    @ObservedObject var sessionManager: ShellSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [PersistedSessionState] = []
    @State private var selectedSessions: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session History")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.rtTextPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.rtTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.rtBackgroundLight)

            Divider()
                .background(Color.rtBorderSubtle)

            // Session list
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.rtTextDisabled)

                    Text("No saved sessions")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sessions) { session in
                            HistorySessionRow(
                                session: session,
                                isSelected: selectedSessions.contains(session.id),
                                onToggle: { toggleSelection(session.id) },
                                onRestore: { restoreSession(session.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            }

            // Action bar
            if !sessions.isEmpty {
                Divider()
                    .background(Color.rtBorderSubtle)

                HStack(spacing: 12) {
                    // Select all / deselect all
                    Button(action: toggleSelectAll) {
                        Text(selectedSessions.isEmpty ? "Select All" : "Deselect All")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.rtAccentGreen)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Delete selected
                    Button(action: { showDeleteConfirmation = true }) {
                        Label("Delete Selected", systemImage: "trash")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedSessions.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.rtBackgroundLight)
            }
        }
        .frame(width: 600, height: 500)
        .background(Color.rtBackgroundDark)
        .onAppear(perform: loadSessions)
        .alert("Delete Sessions", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSessions()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedSessions.count) session\(selectedSessions.count == 1 ? "" : "s")? This cannot be undone.")
        }
    }

    private func loadSessions() {
        sessions = sessionManager.getPersistedSessions()
    }

    private func toggleSelection(_ sessionId: UUID) {
        if selectedSessions.contains(sessionId) {
            selectedSessions.remove(sessionId)
        } else {
            selectedSessions.insert(sessionId)
        }
    }

    private func toggleSelectAll() {
        if selectedSessions.isEmpty {
            selectedSessions = Set(sessions.map { $0.id })
        } else {
            selectedSessions.removeAll()
        }
    }

    private func restoreSession(_ sessionId: UUID) {
        sessionManager.restoreSession(sessionId)
        dismiss()
    }

    private func deleteSessions() {
        for sessionId in selectedSessions {
            sessionManager.deletePersistedSession(sessionId)
        }
        selectedSessions.removeAll()
        loadSessions()
    }
}

// MARK: - History Session Row

struct HistorySessionRow: View {
    let session: PersistedSessionState
    let isSelected: Bool
    let onToggle: () -> Void
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .rtAccentGreen : .rtTextSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Working directory
                Text(session.workingDirectory)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.rtTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Metadata
                HStack(spacing: 16) {
                    Label(session.shellType, systemImage: "terminal")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)

                    Label(formattedDate(session.createdAt), systemImage: "calendar")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)

                    Label(formattedDate(session.lastAccessedAt), systemImage: "clock")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.rtTextSecondary)
                }
            }

            Spacer()

            // Restore button
            Button(action: onRestore) {
                Text("Restore")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.rtBackgroundDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.rtAccentGreen)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.rtBackgroundLight)
        .cornerRadius(8)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct SessionRestorationView_Previews: PreviewProvider {
    static var previews: some View {
        SessionRestorationView(
            sessions: [
                PersistedSessionState(
                    id: UUID(),
                    workingDirectory: "/Users/rick/Projects/portal-gun",
                    shellType: "/bin/zsh",
                    createdAt: Date().addingTimeInterval(-3600),
                    lastAccessedAt: Date().addingTimeInterval(-1800)
                ),
                PersistedSessionState(
                    id: UUID(),
                    workingDirectory: "/Users/morty/code",
                    shellType: "/bin/bash",
                    createdAt: Date().addingTimeInterval(-7200),
                    lastAccessedAt: Date().addingTimeInterval(-3600)
                )
            ],
            onRestore: { _ in },
            onDismiss: { }
        )
        .frame(width: 500, height: 500)
        .background(Color.black)
    }
}
