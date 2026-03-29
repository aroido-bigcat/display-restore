import Foundation

public struct DiagnosticsEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var eventType: String
    public var profileName: String?
    public var score: Int?
    public var actionTaken: String
    public var executionResult: String
    public var verificationResult: String
    public var details: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        profileName: String? = nil,
        score: Int? = nil,
        actionTaken: String,
        executionResult: String,
        verificationResult: String,
        details: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.profileName = profileName
        self.score = score
        self.actionTaken = actionTaken
        self.executionResult = executionResult
        self.verificationResult = verificationResult
        self.details = details
    }
}

public actor DiagnosticsLogger: DiagnosticsStoring {
    private let maxEntries: Int
    public let fileURL: URL

    public init(maxEntries: Int = 200, fileURL: URL? = nil) {
        self.maxEntries = maxEntries
        self.fileURL = fileURL ?? LayoutRecallStorage.fileURL(named: "diagnostics.json")
    }

    public func append(_ entry: DiagnosticsEntry) async throws {
        var entries = try await recentEntries()
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(maxEntries))
        try save(entries)
    }

    public func recentEntries() async throws -> [DiagnosticsEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DiagnosticsEntry].self, from: data)
    }

    private func save(_ entries: [DiagnosticsEntry]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }
}
