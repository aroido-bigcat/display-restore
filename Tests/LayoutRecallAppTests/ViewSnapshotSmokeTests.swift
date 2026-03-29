import AppKit
import Foundation
import ImageIO
import SwiftUI
import Testing
@testable import LayoutRecallApp
@testable import LayoutRecallKit

@MainActor
@Test
func renderMenuAndSettingsSnapshots() async throws {
    let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("layoutrecall-ui-snapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let model = AppModel(
        store: SnapshotProfileStore(profiles: [DisplayProfile.officeDock]),
        settingsStore: SnapshotSettingsStore(settings: AppSettings(launchAtLogin: true)),
        diagnosticsStore: SnapshotDiagnosticsStore(entries: [
            DiagnosticsEntry(
                eventType: DisplayEventType.reconfigured.rawValue,
                profileName: "Office Dock",
                score: 92,
                actionTaken: "auto-restore",
                executionResult: RestoreExecutionOutcome.success.rawValue,
                verificationResult: RestoreVerificationOutcome.success.rawValue,
                details: "A saved profile matched and the restore command completed successfully."
            )
        ]),
        snapshotReader: SnapshotReader(displays: [DisplaySnapshot.sampleLeft, DisplaySnapshot.sampleRight]),
        eventMonitor: NoopDisplayEventMonitor(),
        commandBuilder: SnapshotCommandBuilder(),
        executor: SnapshotExecutor(),
        verifier: SnapshotVerifier(),
        loginItemManager: SnapshotLoginItemManager(),
        autoBootstrap: false
    )

    await model.bootstrap()

    let menuURL = outputDirectory.appendingPathComponent("menu.png", isDirectory: false)
    let settingsURL = outputDirectory.appendingPathComponent("settings.png", isDirectory: false)

    try render(
        view: MenuContentView(model: model),
        to: menuURL,
        minimumSize: CGSize(width: 320, height: 300)
    )
    try render(
        view: SettingsView(model: model),
        to: settingsURL,
        minimumSize: CGSize(width: 560, height: 520)
    )

    #expect(FileManager.default.fileExists(atPath: menuURL.path()))
    #expect(FileManager.default.fileExists(atPath: settingsURL.path()))

    let menuSize = try imageSize(at: menuURL)
    let settingsSize = try imageSize(at: settingsURL)

    #expect(menuSize.width >= 320)
    #expect(menuSize.height >= 300)
    #expect(menuSize.width <= 720)
    #expect(menuSize.height <= 1360)
    #expect(settingsSize.width >= 560)
    #expect(settingsSize.height >= 520)
    #expect(settingsSize.width <= 1360)
}

@MainActor
private func render<Content: View>(
    view: Content,
    to url: URL,
    minimumSize: CGSize
) throws {
    let hostingView = NSHostingView(rootView: view)
    let contentSize = CGSize(
        width: max(minimumSize.width, hostingView.fittingSize.width),
        height: max(minimumSize.height, hostingView.fittingSize.height)
    )
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: contentSize),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.center()
    window.makeKeyAndOrderFront(nil)
    hostingView.frame = NSRect(origin: .zero, size: contentSize)
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    guard let contentView = window.contentView else {
        Issue.record("Failed to get the window content view for snapshot rendering.")
        window.close()
        return
    }

    guard let representation = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
        Issue.record("Failed to create a bitmap representation for the SwiftUI view.")
        window.close()
        return
    }

    contentView.cacheDisplay(in: contentView.bounds, to: representation)
    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        Issue.record("Failed to encode the rendered snapshot as PNG data.")
        window.close()
        return
    }

    try pngData.write(to: url, options: .atomic)
    window.close()
}

private func imageSize(at url: URL) throws -> CGSize {
    guard
        let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
        let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
    else {
        throw CocoaError(.fileReadCorruptFile)
    }

    return CGSize(width: width, height: height)
}

private actor SnapshotProfileStore: ProfileStoring {
    let profiles: [DisplayProfile]

    init(profiles: [DisplayProfile]) {
        self.profiles = profiles
    }

    func loadProfiles() async throws -> [DisplayProfile] {
        profiles
    }

    func saveProfiles(_ profiles: [DisplayProfile]) async throws {}
}

private actor SnapshotSettingsStore: AppSettingsStoring {
    let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func loadSettings() async throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) async throws {}
}

private actor SnapshotDiagnosticsStore: DiagnosticsStoring {
    let entries: [DiagnosticsEntry]

    init(entries: [DiagnosticsEntry]) {
        self.entries = entries
    }

    func recentEntries() async throws -> [DiagnosticsEntry] {
        entries
    }

    func append(_ entry: DiagnosticsEntry) async throws {}
}

private actor SnapshotReader: DisplaySnapshotReading {
    let displays: [DisplaySnapshot]

    init(displays: [DisplaySnapshot]) {
        self.displays = displays
    }

    func currentDisplays() async throws -> [DisplaySnapshot] {
        displays
    }
}

private struct SnapshotCommandBuilder: DisplayCommandBuilding, Sendable {
    func restorePlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan {
        GeneratedLayoutPlan(
            command: DisplayProfile.officeDock.layout.engine.command,
            expectedOrigins: [
                DisplayOrigin(key: DisplaySnapshot.sampleLeft.preferredMatchKey, x: 0, y: 0),
                DisplayOrigin(key: DisplaySnapshot.sampleRight.preferredMatchKey, x: 2560, y: 0)
            ],
            primaryDisplayKey: DisplaySnapshot.sampleLeft.preferredMatchKey
        )
    }

    func swapLeftRightPlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan {
        GeneratedLayoutPlan(
            command: "displayplacer 'id:persistent-left origin:(2560,0) res:2560x1440 hz:60 scaling:off' 'id:persistent-right origin:(0,0) res:2560x1440 hz:60 scaling:off'",
            expectedOrigins: [
                DisplayOrigin(key: DisplaySnapshot.sampleLeft.preferredMatchKey, x: 2560, y: 0),
                DisplayOrigin(key: DisplaySnapshot.sampleRight.preferredMatchKey, x: 0, y: 0)
            ],
            primaryDisplayKey: DisplaySnapshot.sampleLeft.preferredMatchKey
        )
    }
}

private actor SnapshotExecutor: RestoreExecuting {
    func dependencyStatus() async -> RestoreDependencyStatus {
        RestoreDependencyStatus(
            isAvailable: true,
            location: "/usr/local/bin/displayplacer",
            details: "displayplacer available at /usr/local/bin/displayplacer."
        )
    }

    func execute(command: String) async -> RestoreExecutionResult {
        RestoreExecutionResult(
            outcome: .success,
            command: command,
            exitCode: 0,
            details: "Restore command finished successfully."
        )
    }
}

private actor SnapshotVerifier: RestoreVerifying {
    func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult {
        RestoreVerificationResult(
            outcome: .success,
            attempts: 1,
            details: "Display layout matches the expected saved origins."
        )
    }
}

private actor SnapshotLoginItemManager: LoginItemManaging {
    func currentState() async -> LaunchAtLoginState {
        .enabled
    }

    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        enabled ? .enabled : .disabled
    }
}
