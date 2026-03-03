import XCTest
@testable import RickTerminal

/// Unit tests for KanbanCard model
class KanbanCardTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // Given/When
        let card = KanbanCard(title: "Test Card")

        // Then
        XCTAssertEqual(card.title, "Test Card")
        XCTAssertEqual(card.description, "")
        XCTAssertEqual(card.status, .backlog)
        XCTAssertTrue(card.labels.isEmpty)
        XCTAssertEqual(card.priority, .medium)
        XCTAssertNil(card.dueDate)
        XCTAssertNil(card.assignee)
        XCTAssertNil(card.ticketRef)
        XCTAssertNil(card.estimatedPoints)
        XCTAssertNil(card.completedAt)
        XCTAssertEqual(card.source, .manual)
    }

    func testFullInitialization() {
        // Given
        let now = Date()
        let dueDate = now.addingTimeInterval(86400)
        let labels = [CardLabel.bug, CardLabel.feature]

        // When
        let card = KanbanCard(
            title: "Complex Card",
            description: "Test description",
            status: .inProgress,
            labels: labels,
            priority: .high,
            createdAt: now,
            updatedAt: now,
            dueDate: dueDate,
            assignee: "Morty",
            ticketRef: "RT-001",
            estimatedPoints: 5,
            completedAt: nil,
            source: .claude(sourceHash: "abc123")
        )

        // Then
        XCTAssertEqual(card.title, "Complex Card")
        XCTAssertEqual(card.description, "Test description")
        XCTAssertEqual(card.status, .inProgress)
        XCTAssertEqual(card.labels.count, 2)
        XCTAssertEqual(card.priority, .high)
        XCTAssertEqual(card.dueDate, dueDate)
        XCTAssertEqual(card.assignee, "Morty")
        XCTAssertEqual(card.ticketRef, "RT-001")
        XCTAssertEqual(card.estimatedPoints, 5)
        XCTAssertNil(card.completedAt)
    }

    // MARK: - Encoding/Decoding Tests

    func testEncodeDecode() throws {
        // Given
        let original = KanbanCard(
            title: "Test Card",
            description: "Test description",
            status: .review,
            labels: [CardLabel.bug],
            priority: .critical,
            dueDate: Date(),
            assignee: "Rick",
            ticketRef: "RT-042",
            estimatedPoints: 8,
            source: .manual
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KanbanCard.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.priority, original.priority)
        XCTAssertEqual(decoded.assignee, original.assignee)
        XCTAssertEqual(decoded.ticketRef, original.ticketRef)
        XCTAssertEqual(decoded.estimatedPoints, original.estimatedPoints)
        XCTAssertEqual(decoded.source, original.source)
    }

    func testEncodeDecodeWithAllSources() throws {
        // Test all CardSource variants
        let sources: [CardSource] = [
            .manual,
            .claude(sourceHash: "hash123"),
            .ticket(ref: "JIRA-001"),
            .subAgent(agentId: UUID(), taskHash: "task123")
        ]

        for source in sources {
            // Given
            let card = KanbanCard(title: "Test", source: source)

            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(card)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(KanbanCard.self, from: data)

            // Then
            XCTAssertEqual(decoded.source, source, "Failed to encode/decode source: \(source)")
        }
    }

    // MARK: - Mutation Tests

    func testUpdated() {
        // Given
        let original = KanbanCard(title: "Test")
        let originalUpdatedAt = original.updatedAt

        // Wait to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)

        // When
        let updated = original.updated()

        // Then
        XCTAssertGreaterThan(updated.updatedAt, originalUpdatedAt)
        XCTAssertEqual(updated.title, original.title)
        XCTAssertEqual(updated.id, original.id)
    }

    func testWithStatus() {
        // Given
        let card = KanbanCard(title: "Test", status: .backlog)

        // When
        let inProgress = card.withStatus(.inProgress)
        let done = inProgress.withStatus(.done)

        // Then
        XCTAssertEqual(inProgress.status, .inProgress)
        XCTAssertNil(inProgress.completedAt)
        XCTAssertEqual(done.status, .done)
        XCTAssertNotNil(done.completedAt)
    }

    func testWithStatusDoesNotOverwriteCompletedAt() {
        // Given
        let completedDate = Date()
        let card = KanbanCard(title: "Test", status: .done, completedAt: completedDate)

        // When
        let updated = card.withStatus(.done)

        // Then
        XCTAssertEqual(updated.completedAt, completedDate)
    }

    func testAssignedTo() {
        // Given
        let card = KanbanCard(title: "Test")

        // When
        let assigned = card.assignedTo("Rick")
        let unassigned = assigned.assignedTo(nil)

        // Then
        XCTAssertEqual(assigned.assignee, "Rick")
        XCTAssertNil(unassigned.assignee)
    }

    func testWithLabel() {
        // Given
        let card = KanbanCard(title: "Test")

        // When
        let withBug = card.withLabel(.bug)
        let withFeature = withBug.withLabel(.feature)
        let duplicate = withFeature.withLabel(.bug) // Should not add duplicate

        // Then
        XCTAssertEqual(withBug.labels.count, 1)
        XCTAssertEqual(withFeature.labels.count, 2)
        XCTAssertEqual(duplicate.labels.count, 2) // No duplicate
    }

    func testWithoutLabel() {
        // Given
        let card = KanbanCard(title: "Test", labels: [.bug, .feature, .testing])

        // When
        let removed = card.withoutLabel(.feature)

        // Then
        XCTAssertEqual(removed.labels.count, 2)
        XCTAssertFalse(removed.labels.contains(.feature))
        XCTAssertTrue(removed.labels.contains(.bug))
        XCTAssertTrue(removed.labels.contains(.testing))
    }

    // MARK: - Computed Properties Tests

    func testIsOverdue() {
        // Given
        let past = Date().addingTimeInterval(-86400) // 1 day ago
        let future = Date().addingTimeInterval(86400) // 1 day from now

        // When/Then
        let overdueCard = KanbanCard(title: "Overdue", dueDate: past)
        XCTAssertTrue(overdueCard.isOverdue)

        let notDueCard = KanbanCard(title: "Not Due", dueDate: future)
        XCTAssertFalse(notDueCard.isOverdue)

        let noDueDateCard = KanbanCard(title: "No Due Date")
        XCTAssertFalse(noDueDateCard.isOverdue)

        let completedCard = KanbanCard(title: "Done", status: .done, dueDate: past)
        XCTAssertFalse(completedCard.isOverdue) // Terminal status
    }

    func testAgeInDays() {
        // Given
        let threeDaysAgo = Date().addingTimeInterval(-3 * 86400)
        let card = KanbanCard(title: "Old Card", createdAt: threeDaysAgo)

        // When
        let age = card.ageInDays

        // Then
        XCTAssertEqual(age, 3)
    }

    func testHasLabels() {
        // Given
        let withLabels = KanbanCard(title: "Test", labels: [.bug])
        let withoutLabels = KanbanCard(title: "Test")

        // When/Then
        XCTAssertTrue(withLabels.hasLabels)
        XCTAssertFalse(withoutLabels.hasLabels)
    }

    func testIsAssigned() {
        // Given
        let assigned = KanbanCard(title: "Test", assignee: "Rick")
        let unassigned = KanbanCard(title: "Test")
        let emptyAssignee = KanbanCard(title: "Test", assignee: "")

        // When/Then
        XCTAssertTrue(assigned.isAssigned)
        XCTAssertFalse(unassigned.isAssigned)
        XCTAssertFalse(emptyAssignee.isAssigned)
    }

    // MARK: - Source Tracking Tests

    func testIsAutoGenerated() {
        // Given
        let manualCard = KanbanCard(title: "Manual", source: .manual)
        let claudeCard = KanbanCard(title: "Claude", source: .claude(sourceHash: "abc"))
        let subAgentCard = KanbanCard(title: "SubAgent", source: .subAgent(agentId: UUID(), taskHash: "xyz"))
        let ticketCard = KanbanCard(title: "Ticket", source: .ticket(ref: "RT-001"))

        // When/Then
        XCTAssertFalse(manualCard.isAutoGenerated)
        XCTAssertTrue(claudeCard.isAutoGenerated)
        XCTAssertTrue(subAgentCard.isAutoGenerated)
        XCTAssertFalse(ticketCard.isAutoGenerated)
    }

    func testIsManuallyManaged() {
        // Given
        let manualCard = KanbanCard(title: "Manual", source: .manual)
        let claudeCard = KanbanCard(title: "Claude", source: .claude(sourceHash: "abc"))

        // When/Then
        XCTAssertTrue(manualCard.isManuallyManaged)
        XCTAssertFalse(claudeCard.isManuallyManaged)
    }

    func testClaimedByUser() {
        // Given
        let claudeCard = KanbanCard(title: "Claude", source: .claude(sourceHash: "abc"))

        // When
        let claimed = claudeCard.claimedByUser()

        // Then
        XCTAssertEqual(claimed.source, .manual)
        XCTAssertTrue(claimed.isManuallyManaged)
    }

    func testMatchesHash() {
        // Given
        let card = KanbanCard(title: "Test", source: .claude(sourceHash: "hash123"))

        // When/Then
        XCTAssertTrue(card.matchesHash("hash123"))
        XCTAssertFalse(card.matchesHash("different"))
    }

    // MARK: - Sorting Tests

    func testSortByPriority() {
        // Given
        let low = KanbanCard(title: "Low", priority: .low)
        let medium = KanbanCard(title: "Medium", priority: .medium)
        let high = KanbanCard(title: "High", priority: .high)
        let critical = KanbanCard(title: "Critical", priority: .critical)

        var cards = [low, medium, critical, high]

        // When
        cards.sort(by: KanbanCard.byPriority)

        // Then (highest first)
        XCTAssertEqual(cards[0].priority, .critical)
        XCTAssertEqual(cards[1].priority, .high)
        XCTAssertEqual(cards[2].priority, .medium)
        XCTAssertEqual(cards[3].priority, .low)
    }

    func testSortByCreatedAt() {
        // Given
        let old = KanbanCard(title: "Old", createdAt: Date().addingTimeInterval(-100))
        let new = KanbanCard(title: "New", createdAt: Date())

        var cards = [old, new]

        // When
        cards.sort(by: KanbanCard.byCreatedAt)

        // Then (newest first)
        XCTAssertEqual(cards[0].title, "New")
        XCTAssertEqual(cards[1].title, "Old")
    }

    func testSortByDueDate() {
        // Given
        let noDueDate = KanbanCard(title: "No Due Date")
        let soon = KanbanCard(title: "Soon", dueDate: Date().addingTimeInterval(86400))
        let later = KanbanCard(title: "Later", dueDate: Date().addingTimeInterval(2 * 86400))

        var cards = [noDueDate, later, soon]

        // When
        cards.sort(by: KanbanCard.byDueDate)

        // Then (earliest first, nil last)
        XCTAssertEqual(cards[0].title, "Soon")
        XCTAssertEqual(cards[1].title, "Later")
        XCTAssertEqual(cards[2].title, "No Due Date")
    }

    func testSortByUpdatedAt() {
        // Given
        let old = KanbanCard(title: "Old", updatedAt: Date().addingTimeInterval(-100))
        let new = KanbanCard(title: "New", updatedAt: Date())

        var cards = [old, new]

        // When
        cards.sort(by: KanbanCard.byUpdatedAt)

        // Then (most recent first)
        XCTAssertEqual(cards[0].title, "New")
        XCTAssertEqual(cards[1].title, "Old")
    }
}

// MARK: - CardPriority Tests

class CardPriorityTests: XCTestCase {

    func testPriorityComparable() {
        XCTAssertTrue(CardPriority.low < CardPriority.medium)
        XCTAssertTrue(CardPriority.medium < CardPriority.high)
        XCTAssertTrue(CardPriority.high < CardPriority.critical)
    }

    func testPriorityDisplayNames() {
        XCTAssertEqual(CardPriority.low.displayName, "Low")
        XCTAssertEqual(CardPriority.medium.displayName, "Medium")
        XCTAssertEqual(CardPriority.high.displayName, "High")
        XCTAssertEqual(CardPriority.critical.displayName, "Critical")
    }

    func testPriorityIconNames() {
        XCTAssertEqual(CardPriority.low.iconName, "arrow.down")
        XCTAssertEqual(CardPriority.medium.iconName, "minus")
        XCTAssertEqual(CardPriority.high.iconName, "arrow.up")
        XCTAssertEqual(CardPriority.critical.iconName, "exclamationmark.triangle")
    }

    func testPriorityEncodeDecode() throws {
        for priority in CardPriority.allCases {
            let encoded = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(CardPriority.self, from: encoded)
            XCTAssertEqual(decoded, priority)
        }
    }
}

// MARK: - CardStatus Tests

class CardStatusTests: XCTestCase {

    func testStatusDisplayNames() {
        XCTAssertEqual(CardStatus.backlog.displayName, "Backlog")
        XCTAssertEqual(CardStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(CardStatus.review.displayName, "Review")
        XCTAssertEqual(CardStatus.done.displayName, "Done")
        XCTAssertEqual(CardStatus.blocked.displayName, "Blocked")
    }

    func testStatusIconNames() {
        XCTAssertEqual(CardStatus.backlog.iconName, "tray")
        XCTAssertEqual(CardStatus.inProgress.iconName, "arrow.right.circle")
        XCTAssertEqual(CardStatus.review.iconName, "eye")
        XCTAssertEqual(CardStatus.done.iconName, "checkmark.circle")
        XCTAssertEqual(CardStatus.blocked.iconName, "xmark.octagon")
    }

    func testIsTerminal() {
        XCTAssertTrue(CardStatus.done.isTerminal)
        XCTAssertFalse(CardStatus.backlog.isTerminal)
        XCTAssertFalse(CardStatus.inProgress.isTerminal)
        XCTAssertFalse(CardStatus.review.isTerminal)
        XCTAssertFalse(CardStatus.blocked.isTerminal)
    }

    func testIsActive() {
        XCTAssertTrue(CardStatus.inProgress.isActive)
        XCTAssertTrue(CardStatus.review.isActive)
        XCTAssertFalse(CardStatus.backlog.isActive)
        XCTAssertFalse(CardStatus.done.isActive)
        XCTAssertFalse(CardStatus.blocked.isActive)
    }

    func testStatusEncodeDecode() throws {
        for status in CardStatus.allCases {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(CardStatus.self, from: encoded)
            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - CardLabel Tests

class CardLabelTests: XCTestCase {

    func testLabelInitialization() {
        let label = CardLabel(name: "Custom", color: "#FF5733")
        XCTAssertEqual(label.name, "Custom")
        XCTAssertEqual(label.color, "#FF5733")
    }

    func testLabelEquality() {
        let id = UUID()
        let label1 = CardLabel(id: id, name: "Test", color: "#FF0000")
        let label2 = CardLabel(id: id, name: "Test", color: "#FF0000")
        let label3 = CardLabel(name: "Different", color: "#FF0000")

        XCTAssertEqual(label1, label2)
        XCTAssertNotEqual(label1, label3)
    }

    func testPresetLabels() {
        XCTAssertEqual(CardLabel.bug.name, "Bug")
        XCTAssertEqual(CardLabel.feature.name, "Feature")
        XCTAssertEqual(CardLabel.techDebt.name, "Tech Debt")
        XCTAssertEqual(CardLabel.docs.name, "Docs")
        XCTAssertEqual(CardLabel.testing.name, "Testing")
        XCTAssertEqual(CardLabel.design.name, "Design")
        XCTAssertEqual(CardLabel.security.name, "Security")
        XCTAssertEqual(CardLabel.performance.name, "Performance")
    }

    func testPresetsArray() {
        let presets = CardLabel.presets
        XCTAssertEqual(presets.count, 8)
    }

    func testLabelEncodeDecode() throws {
        let original = CardLabel(name: "Test", color: "#ABCDEF")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CardLabel.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.color, original.color)
    }
}
