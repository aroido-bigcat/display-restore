import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@Test
func liveUIHarnessClicksPersistExpectedState() async throws {
    guard ProcessInfo.processInfo.environment["LAYOUTRECALL_RUN_LIVE_UI_TESTS"] == "1" else {
        return
    }

    guard AXIsProcessTrusted() else {
        Issue.record("Accessibility access is required for live UI automation tests.")
        return
    }

    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let appBundlePath = NSString(
        string: ProcessInfo.processInfo.environment["LAYOUTRECALL_UI_APP_BUNDLE_PATH"]
            ?? "~/Applications/LayoutRecall.app"
    ).expandingTildeInPath

    let launchStart = Date()
    let openProcess = Process()
    openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    openProcess.arguments = [
        "-n",
        appBundlePath,
        "--args",
        "--ui-test-harness",
        "--open-settings-on-launch",
        "--storage-root",
        tempRoot.path
    ]

    try openProcess.run()
    openProcess.waitUntilExit()

    let runningApp = try await waitForRunningApplication(
        bundleIdentifier: "com.aroido.layoutrecall",
        launchedAfter: launchStart
    )
    defer {
        runningApp.terminate()
    }

    _ = try await waitForWindowBounds(
        ownerPID: runningApp.processIdentifier,
        description: "menu harness window"
    ) { bounds in
        bounds.width >= 280 && bounds.width <= 340 && bounds.height >= 220 && bounds.height <= 400
    }

    _ = try await waitForWindowBounds(
        ownerPID: runningApp.processIdentifier,
        description: "settings window"
    ) { bounds in
        bounds.width >= 700 && bounds.height >= 500
    }
}

private func waitForRunningApplication(
    bundleIdentifier: String,
    launchedAfter launchDate: Date,
    timeoutNanoseconds: UInt64 = 10_000_000_000,
    pollNanoseconds: UInt64 = 100_000_000
) async throws -> NSRunningApplication {
    let attempts = max(1, Int(timeoutNanoseconds / pollNanoseconds))

    for _ in 0..<attempts {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter({ ($0.launchDate ?? .distantPast) >= launchDate.addingTimeInterval(-1) })
            .sorted(by: { ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast) })
            .first
        {
            return app
        }

        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    throw UIAutomationError.timedOut("application \(bundleIdentifier) to launch")
}

private func waitForWindowBounds(
    ownerPID: pid_t,
    description: String,
    timeoutNanoseconds: UInt64 = 10_000_000_000,
    pollNanoseconds: UInt64 = 100_000_000,
    where matches: (CGRect) -> Bool
) async throws -> CGRect {
    let attempts = max(1, Int(timeoutNanoseconds / pollNanoseconds))

    for _ in 0..<attempts {
        if let bounds = currentWindowBounds(ownerPID: ownerPID).first(where: matches) {
            return bounds
        }

        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    throw UIAutomationError.timedOut(description)
}

private enum UIAutomationError: LocalizedError {
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .timedOut(let description):
            return description
        }
    }
}

private func currentWindowBounds(ownerPID: pid_t) -> [CGRect] {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []

    return windows.compactMap { window in
        guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
              pid == ownerPID,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? CGFloat,
              let y = bounds["Y"] as? CGFloat,
              let width = bounds["Width"] as? CGFloat,
              let height = bounds["Height"] as? CGFloat
        else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
