import Foundation
import Testing
@testable import LayoutRecallKit

@Test
func diagnosticsStorePersistsEntriesAndCapsItsHistory() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = tempDirectory.appendingPathComponent("diagnostics.json", isDirectory: false)
    let store = DiagnosticsLogger(maxEntries: 2, fileURL: fileURL)

    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    try await store.append(
        DiagnosticsEntry(
            eventType: "manual",
            profileName: "Workspace 1",
            score: 80,
            actionTaken: "manual-fix",
            executionResult: "success",
            verificationResult: "success",
            details: "First restore."
        )
    )

    try await store.append(
        DiagnosticsEntry(
            eventType: "reconfigured",
            profileName: "Workspace 2",
            score: 72,
            actionTaken: "auto-restore",
            executionResult: "success",
            verificationResult: "failed",
            details: "Second restore."
        )
    )

    try await store.append(
        DiagnosticsEntry(
            eventType: "wake",
            profileName: nil,
            score: nil,
            actionTaken: "idle",
            executionResult: "skipped",
            verificationResult: "skipped",
            details: "Third restore."
        )
    )

    let reloadedStore = DiagnosticsLogger(maxEntries: 2, fileURL: fileURL)
    let entries = try await reloadedStore.recentEntries()

    #expect(entries.count == 2)
    #expect(entries.first?.details == "Third restore.")
    #expect(entries.last?.details == "Second restore.")
}
