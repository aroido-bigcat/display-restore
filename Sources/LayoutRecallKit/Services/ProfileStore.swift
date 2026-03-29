import Foundation

public actor ProfileStore: ProfileStoring {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? LayoutRecallStorage.fileURL(named: "profiles.json")
    }

    public func loadProfiles() async throws -> [DisplayProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([DisplayProfile].self, from: data)
    }

    public func saveProfiles(_ profiles: [DisplayProfile]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }
}
