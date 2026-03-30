import AppKit
import Foundation
import Testing
@testable import LayoutRecallApp
@testable import LayoutRecallKit

@MainActor
@Test
func liveActionHandlersExercisePersistedRestoreAndUpdateFlows() async throws {
    guard ProcessInfo.processInfo.environment["LAYOUTRECALL_RUN_LIVE_E2E"] == "1" else {
        return
    }

    await wakeDisplaysIfPossible()

    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let profileStore = ProfileStore(fileURL: tempRoot.appendingPathComponent("profiles.json", isDirectory: false))
    let settingsStore = AppSettingsStore(fileURL: tempRoot.appendingPathComponent("settings.json", isDirectory: false))
    let diagnosticsStore = DiagnosticsLogger(fileURL: tempRoot.appendingPathComponent("diagnostics.json", isDirectory: false))
    let snapshotReader = DisplaySnapshotReader()
    let commandBuilder = DisplayplacerCommandBuilder()
    let executor = LiveRestoreExecutorStub()
    let installer = LiveDependencyInstallerStub()
    let verifier = LiveRestoreVerifierStub()
    let shortcutManager = LiveShortcutManagerStub()
    let updateInstaller = LiveUpdateInstallerStub()
    let terminationRecorder = LiveTerminationRecorder()

    try await settingsStore.saveSettings(
        AppSettings(
            launchAtLogin: false,
            shortcuts: ShortcutSettings(),
            automaticallyCheckForUpdates: false,
            skippedReleaseVersion: nil
        )
    )

    let updateRelease = AppRelease(
        tagName: "v9.9.9",
        version: "9.9.9",
        assetName: "LayoutRecall-9.9.9-macos.zip",
        downloadURL: URL(string: "https://example.com/LayoutRecall-9.9.9-macos.zip")!,
        publishedAt: nil,
        releaseNotes: "Synthetic live E2E release."
    )

    let model = AppModel(
        store: profileStore,
        settingsStore: settingsStore,
        diagnosticsStore: diagnosticsStore,
        snapshotReader: snapshotReader,
        eventMonitor: NoopDisplayEventMonitor(),
        commandBuilder: commandBuilder,
        executor: executor,
        dependencyInstaller: installer,
        verifier: verifier,
        loginItemManager: LiveLoginItemManagerStub(),
        shortcutManager: shortcutManager,
        updateChecker: LiveUpdateCheckerStub(release: updateRelease),
        updateInstaller: updateInstaller,
        updatePrompt: NoopAppUpdatePrompt(),
        terminateApplication: {
            terminationRecorder.record()
        },
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    let displays = try await snapshotReader.currentDisplays()
    #expect(!displays.isEmpty)

    model.installDisplayplacer()
    await waitForLiveCondition("install dependency action") {
        model.diagnostics.first?.actionTaken == "manual-install"
    }

    model.saveCurrentLayout()
    await waitForLiveCondition("save profile") {
        model.profiles.count == 1
            && model.diagnostics.first?.actionTaken == "save-profile"
    }

    let persistedProfiles = try await profileStore.loadProfiles()
    #expect(persistedProfiles.count == 1)
    let profileID = try #require(model.profiles.first?.id)

    model.renameProfile(profileID, to: "Desk")
    await waitForLiveCondition("rename profile") {
        guard let persistedProfile = try? await profileStore.loadProfiles().first else {
            return false
        }

        return model.profiles.first?.name == "Desk"
            && persistedProfile.name == "Desk"
    }

    model.setConfidenceThreshold(profileID, to: 77)
    await waitForLiveCondition("set confidence threshold") {
        guard let persistedProfile = try? await profileStore.loadProfiles().first else {
            return false
        }

        return model.profiles.first?.settings.confidenceThreshold == 77
            && persistedProfile.settings.confidenceThreshold == 77
    }

    model.setProfileAutoRestore(profileID, to: false)
    await waitForLiveCondition("disable profile auto restore") {
        guard let persistedProfile = try? await profileStore.loadProfiles().first else {
            return false
        }

        return model.profiles.first?.settings.autoRestore == false
            && persistedProfile.settings.autoRestore == false
            && model.autoRestoreEnabled == false
    }

    model.setProfileAutoRestore(profileID, to: true)
    await waitForLiveCondition("enable profile auto restore") {
        guard let persistedProfile = try? await profileStore.loadProfiles().first else {
            return false
        }

        return model.profiles.first?.settings.autoRestore == true
            && persistedProfile.settings.autoRestore == true
            && model.autoRestoreEnabled == true
    }

    model.fixNow()
    await waitForLiveCondition("manual fix") {
        model.diagnostics.first?.actionTaken == "manual-fix"
    }

    #expect(model.lastCommand.contains("displayplacer"))

    if displays.count == 2 {
        model.swapLeftRight()
        await waitForLiveCondition("swap left right") {
            model.diagnostics.first?.actionTaken == "swap-left-right"
        }
    }

    model.setAutoRestore(false)
    await waitForLiveCondition("disable auto restore") {
        model.autoRestoreEnabled == false
            && model.profiles.first?.settings.autoRestore == false
    }

    model.setAutoRestore(true)
    await waitForLiveCondition("enable auto restore") {
        model.autoRestoreEnabled == true
            && model.profiles.first?.settings.autoRestore == true
    }

    model.setShortcut(
        ShortcutBinding(
            keyCode: 15,
            modifiersRawValue: NSEvent.ModifierFlags([.command, .option]).rawValue,
            keyDisplay: "R"
        ),
        for: .fixNow
    )
    model.setShortcut(
        ShortcutBinding(
            keyCode: 1,
            modifiersRawValue: NSEvent.ModifierFlags([.command, .option]).rawValue,
            keyDisplay: "S"
        ),
        for: .saveCurrentLayout
    )
    model.setShortcut(
        ShortcutBinding(
            keyCode: 13,
            modifiersRawValue: NSEvent.ModifierFlags([.command, .option]).rawValue,
            keyDisplay: "W"
        ),
        for: .swapLeftRight
    )
    await waitForLiveCondition("set shortcuts") {
        guard let shortcuts = await shortcutManager.latestShortcuts() else {
            return false
        }

        return shortcuts.fixNow?.keyDisplay == "R"
            && shortcuts.saveCurrentLayout?.keyDisplay == "S"
            && shortcuts.swapLeftRight?.keyDisplay == "W"
    }

    model.setShortcut(nil, for: .fixNow)
    model.setShortcut(nil, for: .saveCurrentLayout)
    model.setShortcut(nil, for: .swapLeftRight)
    await waitForLiveCondition("clear shortcuts") {
        guard let shortcuts = await shortcutManager.latestShortcuts() else {
            return false
        }

        return shortcuts.fixNow == nil
            && shortcuts.saveCurrentLayout == nil
            && shortcuts.swapLeftRight == nil
    }

    model.setLaunchAtLogin(true)
    await waitForLiveCondition("enable launch at login") {
        guard let settings = try? await settingsStore.loadSettings() else {
            return false
        }

        return model.launchAtLoginEnabled
            && settings.launchAtLogin
    }

    model.setLaunchAtLogin(false)
    await waitForLiveCondition("disable launch at login") {
        guard let settings = try? await settingsStore.loadSettings() else {
            return false
        }

        return !model.launchAtLoginEnabled
            && !settings.launchAtLogin
    }

    model.setAutomaticUpdateChecks(true)
    await waitForLiveCondition("enable automatic update checks") {
        guard let settings = try? await settingsStore.loadSettings() else {
            return false
        }

        return model.automaticUpdateChecksEnabled
            && settings.automaticallyCheckForUpdates
            && model.updateState == .available(updateRelease)
    }

    model.setAutomaticUpdateChecks(false)
    await waitForLiveCondition("disable automatic update checks") {
        guard let settings = try? await settingsStore.loadSettings() else {
            return false
        }

        return !model.automaticUpdateChecksEnabled
            && !settings.automaticallyCheckForUpdates
            && model.updateState == .idle
    }

    model.checkForUpdatesNow()
    await waitForLiveCondition("check updates") {
        model.updateState == .available(updateRelease)
    }

    model.skipAvailableUpdateVersion()
    await waitForLiveCondition("skip update") {
        model.updateState == .skipped(updateRelease)
            && model.skippedReleaseVersion == "9.9.9"
    }

    model.clearSkippedUpdateVersion()
    await waitForLiveCondition("clear skipped update") {
        model.skippedReleaseVersion == nil
    }

    model.installAvailableUpdate()
    await waitForLiveCondition("install update") {
        let installedRelease = await updateInstaller.installedRelease()
        return installedRelease == updateRelease
            && terminationRecorder.count() == 1
            && model.updateState == .installing(updateRelease)
    }
}

@MainActor
private func waitForLiveCondition(
    _ step: String,
    timeoutNanoseconds: UInt64 = 20_000_000_000,
    pollNanoseconds: UInt64 = 100_000_000,
    _ predicate: @escaping @MainActor () async -> Bool
) async {
    print("E2E step: \(step)")
    let attempts = max(1, Int(timeoutNanoseconds / pollNanoseconds))

    for _ in 0..<attempts {
        if await predicate() {
            return
        }

        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    Issue.record("Timed out waiting for live E2E state at step: \(step)")
}

@MainActor
private func wakeDisplaysIfPossible() async {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["caffeinate", "-u", "-t", "2"]

    do {
        try process.run()
        process.waitUntilExit()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    } catch {
        return
    }
}

private final class NoopDisplayEventMonitor: DisplayEventMonitoring {
    func start(handler: @escaping @Sendable (DisplayEvent) -> Void) {}
    func stop() {}
}

private actor LiveShortcutManagerStub: ShortcutManaging {
    private var latestConfiguration = ShortcutSettings()

    func configure(
        shortcuts: ShortcutSettings,
        handler: @escaping @Sendable (ShortcutAction) -> Void
    ) async throws {
        latestConfiguration = shortcuts
    }

    func latestShortcuts() -> ShortcutSettings? {
        latestConfiguration
    }
}

private actor LiveRestoreExecutorStub: RestoreExecuting {
    private let dependency = RestoreDependencyStatus(
        isAvailable: true,
        location: "/opt/homebrew/bin/displayplacer",
        details: L10n.t("restoreExecutor.availableAt", "/opt/homebrew/bin/displayplacer")
    )
    private var executedCommands: [String] = []

    func dependencyStatus() async -> RestoreDependencyStatus {
        dependency
    }

    func execute(command: String) async -> RestoreExecutionResult {
        executedCommands.append(command)
        return RestoreExecutionResult(
            outcome: .success,
            command: command,
            exitCode: 0,
            stdout: "",
            stderr: "",
            duration: 0.01,
            details: L10n.t("restoreExecutor.success")
        )
    }

    func commands() -> [String] {
        executedCommands
    }
}

private actor LiveDependencyInstallerStub: DependencyInstalling {
    private var calls = 0

    func installDisplayplacerIfNeeded() async -> DependencyInstallResult {
        calls += 1
        return DependencyInstallResult(
            outcome: .alreadyInstalled,
            dependency: "displayplacer",
            location: "/opt/homebrew/bin/displayplacer",
            details: L10n.t("dependencyInstaller.alreadyInstalled", "/opt/homebrew/bin/displayplacer")
        )
    }

    func installCallCount() -> Int {
        calls
    }
}

private actor LiveRestoreVerifierStub: RestoreVerifying {
    func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult {
        RestoreVerificationResult(
            outcome: .success,
            attempts: 1,
            details: L10n.t("verification.success")
        )
    }
}

private actor LiveUpdateCheckerStub: AppUpdateChecking {
    private let release: AppRelease

    init(release: AppRelease) {
        self.release = release
    }

    func fetchLatestRelease() async throws -> AppRelease? {
        release
    }
}

private actor LiveUpdateInstallerStub: AppUpdateInstalling {
    private var release: AppRelease?

    func prepareUpdateInstallation(release: AppRelease, replacing bundleURL: URL) async throws {
        self.release = release
    }

    func installedRelease() -> AppRelease? {
        release
    }
}

@MainActor
private final class LiveTerminationRecorder {
    private var invocations = 0

    func record() {
        invocations += 1
    }

    func count() -> Int {
        invocations
    }
}

private actor LiveLoginItemManagerStub: LoginItemManaging {
    func currentState() async -> LaunchAtLoginState {
        .disabled
    }

    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        enabled ? .enabled : .disabled
    }
}
