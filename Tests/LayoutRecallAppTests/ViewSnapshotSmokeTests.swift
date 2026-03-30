import AppKit
import Foundation
import ImageIO
import SwiftUI
import Testing
@testable import LayoutRecallApp
@testable import LayoutRecallKit

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil, "AppKit snapshot rendering is only supported in local interactive runs."))
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
                details: L10n.t("restoreDecision.confidentMatch")
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
    let profilesURL = outputDirectory.appendingPathComponent("settings-profiles.png", isDirectory: false)
    let diagnosticsURL = outputDirectory.appendingPathComponent("settings-diagnostics.png", isDirectory: false)
    let shortcutsURL = outputDirectory.appendingPathComponent("settings-shortcuts.png", isDirectory: false)
    let generalURL = outputDirectory.appendingPathComponent("settings-general.png", isDirectory: false)

    let menuLayoutSize = try render(
        view: MenuContentView(model: model, openSettings: {}),
        to: menuURL,
        minimumSize: CGSize(width: 300, height: 260)
    )
    let settingsLayoutSize = try render(
        view: SettingsView(model: model),
        to: settingsURL,
        minimumSize: CGSize(width: 560, height: 520)
    )
    let profilesLayoutSize = try render(
        view: SettingsView(model: model, initialPane: .profiles),
        to: profilesURL,
        minimumSize: CGSize(width: 560, height: 520)
    )
    let diagnosticsLayoutSize = try render(
        view: SettingsView(model: model, initialPane: .diagnostics),
        to: diagnosticsURL,
        minimumSize: CGSize(width: 560, height: 520)
    )
    let shortcutsLayoutSize = try render(
        view: SettingsView(model: model, initialPane: .shortcuts),
        to: shortcutsURL,
        minimumSize: CGSize(width: 560, height: 520)
    )
    let generalLayoutSize = try render(
        view: SettingsView(model: model, initialPane: .general),
        to: generalURL,
        minimumSize: CGSize(width: 560, height: 520)
    )

    #expect(FileManager.default.fileExists(atPath: menuURL.path()))
    #expect(FileManager.default.fileExists(atPath: settingsURL.path()))
    #expect(FileManager.default.fileExists(atPath: profilesURL.path()))
    #expect(FileManager.default.fileExists(atPath: diagnosticsURL.path()))
    #expect(FileManager.default.fileExists(atPath: shortcutsURL.path()))
    #expect(FileManager.default.fileExists(atPath: generalURL.path()))

    let menuImageSize = try imageSize(at: menuURL)
    let settingsImageSize = try imageSize(at: settingsURL)
    let profilesImageSize = try imageSize(at: profilesURL)
    let diagnosticsImageSize = try imageSize(at: diagnosticsURL)
    let shortcutsImageSize = try imageSize(at: shortcutsURL)
    let generalImageSize = try imageSize(at: generalURL)

    #expect(menuLayoutSize.width >= 300)
    #expect(menuLayoutSize.height >= 240)
    #expect(menuLayoutSize.width <= 720)
    #expect(menuLayoutSize.height <= 840)
    #expect(settingsLayoutSize.width >= 760)
    #expect(settingsLayoutSize.height >= 520)
    #expect(settingsLayoutSize.width <= 900)
    #expect(profilesLayoutSize.width >= 760)
    #expect(profilesLayoutSize.height >= 520)
    #expect(profilesLayoutSize.width <= 900)
    #expect(diagnosticsLayoutSize.width >= 760)
    #expect(diagnosticsLayoutSize.height >= 520)
    #expect(diagnosticsLayoutSize.width <= 900)
    #expect(shortcutsLayoutSize.width >= 760)
    #expect(shortcutsLayoutSize.height >= 520)
    #expect(shortcutsLayoutSize.width <= 900)
    #expect(generalLayoutSize.width >= 760)
    #expect(generalLayoutSize.height >= 520)
    #expect(generalLayoutSize.width <= 900)
    #expect(menuImageSize.width >= menuLayoutSize.width)
    #expect(menuImageSize.height >= menuLayoutSize.height)
    #expect(settingsImageSize.width >= settingsLayoutSize.width)
    #expect(settingsImageSize.height >= settingsLayoutSize.height)
    #expect(profilesImageSize.width >= profilesLayoutSize.width)
    #expect(profilesImageSize.height >= profilesLayoutSize.height)
    #expect(diagnosticsImageSize.width >= diagnosticsLayoutSize.width)
    #expect(diagnosticsImageSize.height >= diagnosticsLayoutSize.height)
    #expect(shortcutsImageSize.width >= shortcutsLayoutSize.width)
    #expect(shortcutsImageSize.height >= shortcutsLayoutSize.height)
    #expect(generalImageSize.width >= generalLayoutSize.width)
    #expect(generalImageSize.height >= generalLayoutSize.height)
}

@MainActor
private func render<Content: View>(
    view: Content,
    to url: URL,
    minimumSize: CGSize
) throws -> CGSize {
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
        return contentSize
    }

    guard let representation = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
        Issue.record("Failed to create a bitmap representation for the SwiftUI view.")
        window.close()
        return contentSize
    }

    contentView.cacheDisplay(in: contentView.bounds, to: representation)
    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        Issue.record("Failed to encode the rendered snapshot as PNG data.")
        window.close()
        return contentSize
    }

    try pngData.write(to: url, options: .atomic)
    window.close()
    return contentSize
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
            details: L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer")
        )
    }

    func execute(command: String) async -> RestoreExecutionResult {
        RestoreExecutionResult(
            outcome: .success,
            command: command,
            exitCode: 0,
            details: L10n.t("restoreExecutor.success")
        )
    }
}

private actor SnapshotVerifier: RestoreVerifying {
    func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult {
        RestoreVerificationResult(
            outcome: .success,
            attempts: 1,
            details: L10n.t("verify.match")
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
