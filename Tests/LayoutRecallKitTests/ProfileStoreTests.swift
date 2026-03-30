import Foundation
import Testing
@testable import LayoutRecallKit

@Test
func profileStoreReloadsProfilesSavedWithIso8601Dates() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = tempDirectory.appendingPathComponent("profiles.json", isDirectory: false)
    let store = ProfileStore(fileURL: fileURL)

    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    try await store.saveProfiles([.officeDock])
    let profiles = try await store.loadProfiles()

    #expect(profiles.count == 1)
    #expect(profiles.first?.name == DisplayProfile.officeDock.name)
    #expect(
        abs((profiles.first?.createdAt.timeIntervalSince1970 ?? 0) - DisplayProfile.officeDock.createdAt.timeIntervalSince1970) < 1
    )
    #expect(profiles.first?.layout.engine.command == DisplayProfile.officeDock.layout.engine.command)
}
