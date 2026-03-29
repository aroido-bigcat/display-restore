import Foundation

public actor AppSettingsStore: AppSettingsStoring {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? LayoutRecallStorage.fileURL(named: "settings.json")
    }

    public func loadSettings() async throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return AppSettings()
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func saveSettings(_ settings: AppSettings) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
