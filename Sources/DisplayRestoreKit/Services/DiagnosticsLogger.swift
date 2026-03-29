import Foundation

public struct DiagnosticsEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var eventType: String
    public var profileName: String?
    public var score: Int?
    public var actionTaken: String
    public var details: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        profileName: String? = nil,
        score: Int? = nil,
        actionTaken: String,
        details: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.profileName = profileName
        self.score = score
        self.actionTaken = actionTaken
        self.details = details
    }
}

public actor DiagnosticsLogger {
    private let maxEntries: Int
    private var entries: [DiagnosticsEntry]

    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
        self.entries = []
    }

    public func append(_ entry: DiagnosticsEntry) {
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(maxEntries))
    }

    public func recentEntries() -> [DiagnosticsEntry] {
        entries
    }
}

