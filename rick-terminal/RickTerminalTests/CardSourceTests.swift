import XCTest
@testable import RickTerminal

/// Unit tests for CardSource enum
class CardSourceTests: XCTestCase {

    // MARK: - Computed Properties Tests

    func testIsManual() {
        // Given/When/Then
        XCTAssertTrue(CardSource.manual.isManual)
        XCTAssertFalse(CardSource.claude(sourceHash: "abc").isManual)
        XCTAssertFalse(CardSource.ticket(ref: "RT-001").isManual)
        XCTAssertFalse(CardSource.subAgent(agentId: UUID(), taskHash: "xyz").isManual)
    }

    func testIsClaude() {
        // Given/When/Then
        XCTAssertFalse(CardSource.manual.isClaude)
        XCTAssertTrue(CardSource.claude(sourceHash: "abc").isClaude)
        XCTAssertFalse(CardSource.ticket(ref: "RT-001").isClaude)
        XCTAssertTrue(CardSource.subAgent(agentId: UUID(), taskHash: "xyz").isClaude) // Sub-agent is Claude-generated
    }

    func testSourceHash() {
        // Given
        let claudeSource = CardSource.claude(sourceHash: "abc123")
        let subAgentSource = CardSource.subAgent(agentId: UUID(), taskHash: "xyz789")
        let manualSource = CardSource.manual
        let ticketSource = CardSource.ticket(ref: "RT-001")

        // When/Then
        XCTAssertEqual(claudeSource.sourceHash, "abc123")
        XCTAssertEqual(subAgentSource.sourceHash, "xyz789")
        XCTAssertNil(manualSource.sourceHash)
        XCTAssertNil(ticketSource.sourceHash)
    }

    func testAgentId() {
        // Given
        let agentId = UUID()
        let subAgentSource = CardSource.subAgent(agentId: agentId, taskHash: "xyz")
        let manualSource = CardSource.manual
        let claudeSource = CardSource.claude(sourceHash: "abc")

        // When/Then
        XCTAssertEqual(subAgentSource.agentId, agentId)
        XCTAssertNil(manualSource.agentId)
        XCTAssertNil(claudeSource.agentId)
    }

    func testDisplayName() {
        // Given
        let agentId = UUID()

        // When/Then
        XCTAssertEqual(CardSource.manual.displayName, "Manual")
        XCTAssertEqual(CardSource.claude(sourceHash: "abc").displayName, "Claude")
        XCTAssertEqual(CardSource.ticket(ref: "JIRA-123").displayName, "Ticket JIRA-123")
        XCTAssertEqual(CardSource.subAgent(agentId: agentId, taskHash: "xyz").displayName, "Sub-Agent")
    }

    func testIconName() {
        // Given
        let agentId = UUID()

        // When/Then
        XCTAssertEqual(CardSource.manual.iconName, "hand.tap")
        XCTAssertEqual(CardSource.claude(sourceHash: "abc").iconName, "sparkles")
        XCTAssertEqual(CardSource.ticket(ref: "RT-001").iconName, "ticket")
        XCTAssertEqual(CardSource.subAgent(agentId: agentId, taskHash: "xyz").iconName, "person.crop.circle.badge.clock")
    }

    // MARK: - Equality Tests

    func testEquality() {
        // Given
        let agentId1 = UUID()
        let agentId2 = UUID()

        // When/Then - Manual
        XCTAssertEqual(CardSource.manual, CardSource.manual)

        // Claude - same hash
        XCTAssertEqual(
            CardSource.claude(sourceHash: "abc"),
            CardSource.claude(sourceHash: "abc")
        )

        // Claude - different hash
        XCTAssertNotEqual(
            CardSource.claude(sourceHash: "abc"),
            CardSource.claude(sourceHash: "xyz")
        )

        // Ticket - same ref
        XCTAssertEqual(
            CardSource.ticket(ref: "RT-001"),
            CardSource.ticket(ref: "RT-001")
        )

        // Ticket - different ref
        XCTAssertNotEqual(
            CardSource.ticket(ref: "RT-001"),
            CardSource.ticket(ref: "RT-002")
        )

        // SubAgent - same agentId and hash
        XCTAssertEqual(
            CardSource.subAgent(agentId: agentId1, taskHash: "abc"),
            CardSource.subAgent(agentId: agentId1, taskHash: "abc")
        )

        // SubAgent - different agentId
        XCTAssertNotEqual(
            CardSource.subAgent(agentId: agentId1, taskHash: "abc"),
            CardSource.subAgent(agentId: agentId2, taskHash: "abc")
        )

        // Different types
        XCTAssertNotEqual(CardSource.manual, CardSource.claude(sourceHash: "abc"))
    }

    // MARK: - Hashable Tests

    func testHashable() {
        // Given
        let agentId = UUID()
        let sources: Set<CardSource> = [
            .manual,
            .claude(sourceHash: "abc"),
            .claude(sourceHash: "abc"), // Duplicate - should be ignored
            .ticket(ref: "RT-001"),
            .subAgent(agentId: agentId, taskHash: "xyz")
        ]

        // When/Then - Set should contain 4 unique items
        XCTAssertEqual(sources.count, 4)
    }

    // MARK: - Encoding/Decoding Tests

    func testEncodeDecodeManual() throws {
        // Given
        let source = CardSource.manual

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(source)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CardSource.self, from: data)

        // Then
        XCTAssertEqual(decoded, source)
    }

    func testEncodeDecodeClaude() throws {
        // Given
        let source = CardSource.claude(sourceHash: "abc123")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(source)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CardSource.self, from: data)

        // Then
        XCTAssertEqual(decoded, source)
        XCTAssertEqual(decoded.sourceHash, "abc123")
    }

    func testEncodeDecodeTicket() throws {
        // Given
        let source = CardSource.ticket(ref: "JIRA-456")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(source)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CardSource.self, from: data)

        // Then
        XCTAssertEqual(decoded, source)
    }

    func testEncodeDecodeSubAgent() throws {
        // Given
        let agentId = UUID()
        let source = CardSource.subAgent(agentId: agentId, taskHash: "task789")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(source)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CardSource.self, from: data)

        // Then
        XCTAssertEqual(decoded, source)
        XCTAssertEqual(decoded.agentId, agentId)
        XCTAssertEqual(decoded.sourceHash, "task789")
    }

    func testEncodeDecodeAllVariants() throws {
        // Given
        let agentId = UUID()
        let sources: [CardSource] = [
            .manual,
            .claude(sourceHash: "hash1"),
            .ticket(ref: "RT-001"),
            .subAgent(agentId: agentId, taskHash: "hash2")
        ]

        // When/Then - All variants should encode/decode correctly
        for source in sources {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(source)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CardSource.self, from: data)

            XCTAssertEqual(decoded, source, "Failed to encode/decode: \(source)")
        }
    }

    func testJSONStructure() throws {
        // Given
        let source = CardSource.claude(sourceHash: "testHash123")

        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(source)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "claude")
        XCTAssertEqual(json?["sourceHash"] as? String, "testHash123")
    }

    func testJSONStructureSubAgent() throws {
        // Given
        let agentId = UUID()
        let source = CardSource.subAgent(agentId: agentId, taskHash: "taskHash456")

        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(source)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "subAgent")
        XCTAssertNotNil(json?["agentId"])
        XCTAssertEqual(json?["taskHash"] as? String, "taskHash456")
    }

    // MARK: - Edge Cases

    func testEmptyStrings() throws {
        // Given - Empty strings should still work
        let claudeEmpty = CardSource.claude(sourceHash: "")
        let ticketEmpty = CardSource.ticket(ref: "")
        let subAgentEmpty = CardSource.subAgent(agentId: UUID(), taskHash: "")

        // When/Then - Should encode/decode successfully
        for source in [claudeEmpty, ticketEmpty, subAgentEmpty] {
            let encoded = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(CardSource.self, from: encoded)
            XCTAssertEqual(decoded, source)
        }
    }

    func testSpecialCharacters() throws {
        // Given - Special characters in strings
        let specialChars = "hash@#$%^&*()_+-=[]{}|;:',.<>?/~`"
        let source = CardSource.claude(sourceHash: specialChars)

        // When
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(CardSource.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.sourceHash, specialChars)
    }

    func testUnicodeInStrings() throws {
        // Given - Unicode characters
        let unicode = "🚀 Task-123 日本語"
        let source = CardSource.ticket(ref: unicode)

        // When
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(CardSource.self, from: encoded)

        // Then
        XCTAssertEqual(decoded, source)
    }
}
