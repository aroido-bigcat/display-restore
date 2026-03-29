import Foundation
import Testing
@testable import LayoutRecallKit

@Test
func liveHardwareRestoreCommandExecutesAgainstCurrentLayout() async throws {
    guard ProcessInfo.processInfo.environment["DISPLAY_RESTORE_RUN_LIVE_RESTORE_TESTS"] == "1" else {
        return
    }

    let reader = DisplaySnapshotReader()
    let displays = try await reader.currentDisplays()
    #expect(!displays.isEmpty)

    let plan = try DisplayplacerCommandBuilder().restorePlan(for: displays)
    let executor = DisplayplacerRestoreExecutor(timeout: 30)
    let dependency = await executor.dependencyStatus()
    #expect(dependency.isAvailable)

    let execution = await executor.execute(command: plan.command)
    #expect(execution.outcome == .success)

    let verification = await RestoreVerifier(retryDelays: [250_000_000, 500_000_000]).verify(
        expectedOrigins: plan.expectedOrigins,
        using: reader
    )
    #expect(verification.outcome == .success)
}
