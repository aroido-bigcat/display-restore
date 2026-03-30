import Foundation
import Testing
@testable import LayoutRecallKit

@Test
func liveHardwareRestoreCommandExecutesAgainstCurrentLayout() async throws {
    guard ProcessInfo.processInfo.environment["DISPLAY_RESTORE_RUN_LIVE_RESTORE_TESTS"] == "1" else {
        return
    }

    await wakeDisplaysIfPossible(minimumEnabledDisplays: 1)

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

@Test
func liveHardwareSwapLeftRightRoundTripsBackToOriginalLayout() async throws {
    guard ProcessInfo.processInfo.environment["DISPLAY_RESTORE_RUN_LIVE_SWAP_TESTS"] == "1" else {
        return
    }

    await wakeDisplaysIfPossible(minimumEnabledDisplays: 2)

    let reader = DisplaySnapshotReader()
    let builder = DisplayplacerCommandBuilder()
    let executor = DisplayplacerRestoreExecutor(timeout: 30)
    let verifier = RestoreVerifier(retryDelays: [250_000_000, 500_000_000, 1_000_000_000])

    let dependency = await executor.dependencyStatus()
    #expect(dependency.isAvailable)

    let originalDisplays = try await reader.currentDisplays()
    #expect(originalDisplays.count == 2)

    let originalPlan = try builder.restorePlan(for: originalDisplays)
    let swappedPlan = try builder.swapLeftRightPlan(for: originalDisplays)

    let swapExecution = await executor.execute(command: swappedPlan.command)
    #expect(swapExecution.outcome == .success)

    let swapVerification = await verifier.verify(
        expectedOrigins: swappedPlan.expectedOrigins,
        using: reader
    )
    #expect(swapVerification.outcome == .success)

    let restoreExecution = await executor.execute(command: originalPlan.command)
    #expect(restoreExecution.outcome == .success)

    let restoreVerification = await verifier.verify(
        expectedOrigins: originalPlan.expectedOrigins,
        using: reader
    )
    #expect(restoreVerification.outcome == .success)
}

@Test
func liveHardwareSleepWakeCyclesStayRestorable() async throws {
    guard ProcessInfo.processInfo.environment["DISPLAY_RESTORE_RUN_LIVE_STRESS_TESTS"] == "1" else {
        return
    }

    let reader = DisplaySnapshotReader()
    let builder = DisplayplacerCommandBuilder()
    let executor = DisplayplacerRestoreExecutor(timeout: 30)
    let verifier = RestoreVerifier(retryDelays: [250_000_000, 500_000_000, 1_000_000_000])

    await wakeDisplaysIfPossible(minimumEnabledDisplays: 1)

    let dependency = await executor.dependencyStatus()
    #expect(dependency.isAvailable)

    let baselineDisplays = try await reader.currentDisplays()
    #expect(!baselineDisplays.isEmpty)

    for _ in 0..<3 {
        requestDisplaySleep()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await wakeDisplaysIfPossible(minimumEnabledDisplays: baselineDisplays.count)

        let currentDisplays = try await waitForCurrentDisplays(
            reader: reader,
            minimumCount: baselineDisplays.count
        )
        let restorePlan = try builder.restorePlan(for: currentDisplays)

        let execution = await executor.execute(command: restorePlan.command)
        #expect(execution.outcome == .success)

        let verification = await verifier.verify(
            expectedOrigins: restorePlan.expectedOrigins,
            using: reader
        )
        #expect(verification.outcome == .success)
    }
}

@MainActor
private func wakeDisplaysIfPossible(minimumEnabledDisplays: Int) async {
    for _ in 0..<3 {
        runProcess(arguments: ["caffeinate", "-u", "-t", "2"])
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        if enabledDisplayCount() >= minimumEnabledDisplays {
            return
        }
    }
}

private func waitForCurrentDisplays(
    reader: DisplaySnapshotReader,
    minimumCount: Int,
    timeoutNanoseconds: UInt64 = 10_000_000_000,
    pollNanoseconds: UInt64 = 500_000_000
) async throws -> [DisplaySnapshot] {
    let attempts = max(1, Int(timeoutNanoseconds / pollNanoseconds))

    for _ in 0..<attempts {
        if let displays = try? await reader.currentDisplays(), displays.count >= minimumCount {
            return displays
        }

        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    return try await reader.currentDisplays()
}

private func requestDisplaySleep() {
    runProcess(arguments: ["pmset", "displaysleepnow"])
}

private func enabledDisplayCount() -> Int {
    let output = runProcess(arguments: ["displayplacer", "list"])
    return output
        .components(separatedBy: .newlines)
        .filter { $0.contains("Enabled: true") }
        .count
}

@discardableResult
private func runProcess(arguments: [String]) -> String {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ""
    }

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}
