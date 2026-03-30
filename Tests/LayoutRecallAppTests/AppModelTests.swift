import AppKit
import Foundation
import Testing
@testable import LayoutRecallApp
@testable import LayoutRecallKit

@MainActor
@Test
func bootstrapLoadsPersistedStateAndStartsMonitoring() async {
    let profileStore = ProfileStoreStub(profiles: [.officeDock])
    let settingsStore = AppSettingsStoreStub(settings: AppSettings(launchAtLogin: true))
    let diagnosticsStore = DiagnosticsStoreStub(entries: [
        DiagnosticsEntry(
            eventType: DisplayEventType.manual.rawValue,
            profileName: "Office Dock",
            score: 92,
            actionTaken: "seed",
            executionResult: RestoreVerificationOutcome.skipped.rawValue,
            verificationResult: RestoreVerificationOutcome.skipped.rawValue,
            details: "Seed diagnostic."
        )
    ])
    let snapshotReader = SnapshotReaderStub(displays: [.sampleLeft, .sampleRight])
    let eventMonitor = EventMonitorStub()
    let commandBuilder = StaticCommandBuilder(
        restorePlanResult: sampleRestorePlan(),
        swapPlanResult: sampleSwapPlan()
    )
    let executor = RestoreExecutorStub(
        dependency: .init(
            isAvailable: true,
            location: "/usr/local/bin/displayplacer",
            details: L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer")
        ),
        executionResult: .init(
            outcome: .success,
            command: DisplayProfile.officeDock.layout.engine.command,
            exitCode: 0,
            details: L10n.t("restoreExecutor.success")
        )
    )
    let verifier = RestoreVerifierStub(result: .skipped)
    let loginItemManager = LoginItemManagerStub(current: .enabled, setResponse: .enabled)
    let installer = DependencyInstallerStub()

    let model = AppModel(
        store: profileStore,
        settingsStore: settingsStore,
        diagnosticsStore: diagnosticsStore,
        snapshotReader: snapshotReader,
        eventMonitor: eventMonitor,
        commandBuilder: commandBuilder,
        executor: executor,
        dependencyInstaller: installer,
        verifier: verifier,
        loginItemManager: loginItemManager,
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    #expect(model.profiles.count == 1)
    #expect(model.diagnostics.count == 1)
    #expect(model.launchAtLoginEnabled == true)
    #expect(model.loginItemLine == LaunchAtLoginState.enabled.description)
    #expect(model.dependencyLine == L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer"))
    #expect(model.dependencySummaryLine == L10n.t("restore.dependency.ready"))
    #expect(model.lastCommand == DisplayProfile.officeDock.layout.engine.command)
    #expect(model.menuPrimaryState == .healthy)
    #expect(model.menuPrimaryAction == nil)
    #expect(model.menuQuickActions == [.saveNewProfile])
    #expect(model.restorePrimaryAction == nil)
    #expect(model.restoreSecondaryActions == [.saveNewProfile])
    #expect(model.menuStatusTitle == L10n.t("menu.state.readyProfile", "Office Dock"))
    #expect(model.menuStatusSubtitle == L10n.t("menu.subtitle.ready"))
    #expect(model.menuMetadataLine.contains(L10n.t("confidence.high")))
    #expect(model.canSwapDisplays == true)
    #expect(model.swapAvailabilityLine == L10n.t("settings.swap.ready"))
    #expect(eventMonitor.startCallCount == 1)
}

@MainActor
@Test
func presentationActionsReflectMissingBaseline() async {
    let installer = DependencyInstallerStub()
    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    #expect(model.menuPrimaryState == .noProfiles)
    #expect(model.menuPrimaryAction == .saveNewProfile)
    #expect(model.menuQuickActions.isEmpty)
    #expect(model.restorePrimaryAction == .saveNewProfile)
    #expect(model.restoreSecondaryActions.isEmpty)
    #expect(model.menuStatusSubtitle == L10n.t("menu.subtitle.noProfiles"))
}

@MainActor
@Test
func presentationActionsReflectMissingDependency() async {
    let installer = DependencyInstallerStub()
    let model = AppModel(
        store: ProfileStoreStub(profiles: [.officeDock]),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(
            dependency: .init(
                isAvailable: false,
                location: nil,
                details: L10n.t("restoreExecutor.dependencyMissing")
            )
        ),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    #expect(model.menuPrimaryState == .dependencyMissing)
    #expect(model.menuPrimaryAction == .installDependency)
    #expect(model.menuQuickActions == [.saveNewProfile])
    #expect(model.restorePrimaryAction == .installDependency)
    #expect(model.restoreSecondaryActions == [.saveNewProfile])
    #expect(model.menuStatusSubtitle == L10n.t("menu.subtitle.dependencyMissing"))
    #expect(model.dependencySummaryLine == L10n.t("restore.dependency.missing"))
    #expect(model.canSwapDisplays == false)
    #expect(model.swapAvailabilityLine == L10n.t("settings.swap.dependencyHint"))
}

@MainActor
@Test
func presentationActionsReflectManualRecoveryWithoutLeakingDependencyPath() async {
    var profile = DisplayProfile.officeDock
    profile.settings.autoRestore = false

    let dependencyDetails = L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer")
    let installer = DependencyInstallerStub()
    let model = AppModel(
        store: ProfileStoreStub(profiles: [profile]),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(
            dependency: .init(
                isAvailable: true,
                location: "/usr/local/bin/displayplacer",
                details: dependencyDetails
            )
        ),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    #expect(model.menuPrimaryState == .manualRecovery)
    #expect(model.menuPrimaryAction == .fixNow)
    #expect(model.menuQuickActions == [.saveNewProfile])
    #expect(model.restorePrimaryAction == .fixNow)
    #expect(model.restoreSecondaryActions == [.saveNewProfile])
    #expect(model.menuStatusSubtitle == L10n.t("menu.subtitle.manualRecovery"))
    #expect(model.dependencyLine == dependencyDetails)
    #expect(model.dependencySummaryLine == L10n.t("restore.dependency.ready"))
}

@MainActor
@Test
func bootstrapNormalizesStoredProfileCommandsWithLatestBuilder() async {
    var legacyProfile = DisplayProfile.officeDock
    legacyProfile.layout.engine.command = "displayplacer 'id:persistent-left origin:(0,0) res:2560x1440 hz:60 scaling:off' 'id:persistent-right origin:(2560,0) res:2560x1440 hz:60 scaling:off'"

    let profileStore = ProfileStoreStub(profiles: [legacyProfile])
    let model = AppModel(
        store: profileStore,
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: DisplayplacerCommandBuilder(),
        executor: RestoreExecutorStub(),
        dependencyInstaller: DependencyInstallerStub(),
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    let persistedProfiles = await profileStore.currentProfiles()
    #expect(model.profiles.first?.layout.engine.command.contains("enabled:true") == true)
    #expect(persistedProfiles.first?.layout.engine.command.contains("enabled:true") == true)
}

@MainActor
@Test
func saveCurrentLayoutCreatesAProfileAndDiagnostic() async {
    let profileStore = ProfileStoreStub()
    let diagnosticsStore = DiagnosticsStoreStub()
    let snapshotReader = SnapshotReaderStub(displays: [.sampleLeft, .sampleRight])
    let eventMonitor = EventMonitorStub()
    let plan = sampleRestorePlan()
    let installer = DependencyInstallerStub()

    let model = AppModel(
        store: profileStore,
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: diagnosticsStore,
        snapshotReader: snapshotReader,
        eventMonitor: eventMonitor,
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: plan,
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    model.saveCurrentLayout()

    await waitUntil {
        model.profiles.count == 1 && model.diagnostics.first?.actionTaken == "save-profile"
    }

    #expect(model.profiles.first?.name == L10n.workspaceName(1))
    #expect(model.lastCommand == plan.command)
    #expect(model.statusLine == L10n.t("status.capturedLayout", L10n.workspaceName(1)))
    #expect(model.diagnostics.first?.profileName == L10n.workspaceName(1))
    #expect(await profileStore.currentProfiles().count == 1)
}

@MainActor
@Test
func profileEditsPersistAcrossRenameThresholdAndAutoRestoreChanges() async {
    let profileStore = ProfileStoreStub(profiles: [.officeDock])
    let installer = DependencyInstallerStub()
    let model = AppModel(
        store: profileStore,
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    guard let profileID = model.profiles.first?.id else {
        Issue.record("Expected a bootstrapped profile to exist.")
        return
    }

    model.renameProfile(profileID, to: "Desk Alpha")
    model.setConfidenceThreshold(profileID, to: 85)
    model.setAutoRestore(false)

    await waitUntil {
        let persisted = await profileStore.currentProfiles()
        return persisted.first?.name == "Desk Alpha"
            && persisted.first?.settings.confidenceThreshold == 85
            && persisted.first?.settings.autoRestore == false
    }

    #expect(model.profiles.first?.name == "Desk Alpha")
    #expect(model.profiles.first?.settings.confidenceThreshold == 85)
    #expect(model.profiles.first?.settings.autoRestore == false)
    #expect(model.autoRestoreEnabled == false)

    model.setProfileAutoRestore(profileID, to: true)

    await waitUntil {
        let persisted = await profileStore.currentProfiles()
        return persisted.first?.settings.autoRestore == true
    }

    #expect(model.profiles.first?.settings.autoRestore == true)
    #expect(model.autoRestoreEnabled == true)
}

@MainActor
@Test
func launchAtLoginTogglePersistsPreferenceAndReflectsSystemState() async {
    let settingsStore = AppSettingsStoreStub()
    let loginItemManager = LoginItemManagerStub(current: .disabled, setResponse: .requiresApproval)
    let installer = DependencyInstallerStub()
    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: settingsStore,
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: loginItemManager,
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    model.setLaunchAtLogin(true)

    await waitUntil {
        await settingsStore.latestSavedSettings()?.launchAtLogin == true
            && model.loginItemLine == LaunchAtLoginState.requiresApproval.description
    }

    #expect(model.launchAtLoginEnabled == true)
    #expect(model.statusLine == L10n.t("status.launchAtLoginSaved"))
    #expect(await loginItemManager.requests() == [true])
}

@MainActor
@Test
func shortcutChangesPersistAndReconfigureManager() async {
    let settingsStore = AppSettingsStoreStub()
    let shortcutManager = ShortcutManagerStub()
    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: settingsStore,
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: DependencyInstallerStub(),
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        shortcutManager: shortcutManager,
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    model.setShortcut(sampleShortcut(keyCode: 15, keyDisplay: "R"), for: .fixNow)

    await waitUntil {
        let savedShortcut = await settingsStore.latestSavedSettings()?.shortcuts.fixNow
        let configuredShortcut = await shortcutManager.latestShortcuts()?.fixNow
        return savedShortcut == sampleShortcut(keyCode: 15, keyDisplay: "R")
            && configuredShortcut == sampleShortcut(keyCode: 15, keyDisplay: "R")
    }

    model.setShortcut(sampleShortcut(keyCode: 1, keyDisplay: "S"), for: .fixNow)

    await waitUntil {
        let savedShortcut = await settingsStore.latestSavedSettings()?.shortcuts.fixNow
        let configuredShortcut = await shortcutManager.latestShortcuts()?.fixNow
        return savedShortcut == sampleShortcut(keyCode: 1, keyDisplay: "S")
            && configuredShortcut == sampleShortcut(keyCode: 1, keyDisplay: "S")
    }

    #expect(model.shortcutBinding(for: .fixNow) == sampleShortcut(keyCode: 1, keyDisplay: "S"))
}

@MainActor
@Test
func shortcutTriggerRunsItsMappedAction() async {
    let shortcutManager = ShortcutManagerStub()
    let restorePlan = sampleRestorePlan()
    let executor = RestoreExecutorStub(
        dependency: .init(
            isAvailable: true,
            location: "/usr/local/bin/displayplacer",
            details: L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer")
        ),
        executionResult: .init(
            outcome: .success,
            command: restorePlan.command,
            exitCode: 0,
            details: L10n.t("restoreExecutor.success")
        )
    )
    let model = AppModel(
        store: ProfileStoreStub(profiles: [.officeDock]),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: restorePlan,
            swapPlanResult: sampleSwapPlan()
        ),
        executor: executor,
        dependencyInstaller: DependencyInstallerStub(),
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        shortcutManager: shortcutManager,
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    model.setShortcut(sampleShortcut(keyCode: 15, keyDisplay: "R"), for: .fixNow)

    await waitUntil {
        await shortcutManager.latestShortcuts()?.fixNow == sampleShortcut(keyCode: 15, keyDisplay: "R")
    }

    await shortcutManager.trigger(.fixNow)

    await waitUntil {
        await executor.executedCommands() == [DisplayProfile.officeDock.layout.engine.command]
    }

    #expect(model.lastCommand == DisplayProfile.officeDock.layout.engine.command)
}

@MainActor
@Test
func manualFixStopsWhenDisplayplacerIsMissingAndRecordsWhy() async {
    let diagnosticsStore = DiagnosticsStoreStub()
    let dependency = RestoreDependencyStatus(isAvailable: false, details: L10n.t("restoreExecutor.dependencyMissing"))
    let installer = DependencyInstallerStub(result: .init(
        outcome: .failed,
        dependency: "displayplacer",
        details: L10n.t("dependencyInstaller.displayplacerFailed")
    ))
    let model = AppModel(
        store: ProfileStoreStub(profiles: [.officeDock]),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: diagnosticsStore,
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(dependency: dependency),
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    model.fixNow()

    await waitUntil {
        model.diagnostics.first?.actionTaken == "manual-fix"
    }

    #expect(model.statusLine == dependency.details)
    #expect(model.decisionLine == L10n.t("decision.manualRestoreRequiresDependency"))
    #expect(model.diagnostics.first?.executionResult == RestoreExecutionOutcome.dependencyMissing.rawValue)
}

@MainActor
@Test
func displayEventsTriggerDebouncedAutomaticRestore() async {
    let diagnosticsStore = DiagnosticsStoreStub()
    let eventMonitor = EventMonitorStub()
    let restorePlan = sampleRestorePlan()
    let executor = RestoreExecutorStub(
        dependency: .init(
            isAvailable: true,
            location: "/usr/local/bin/displayplacer",
            details: L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer")
        ),
        executionResult: .init(
            outcome: .success,
            command: restorePlan.command,
            exitCode: 0,
            details: L10n.t("restoreExecutor.success")
        )
    )
    let verifier = RestoreVerifierStub(
        result: .init(
            outcome: .success,
            attempts: 1,
            details: L10n.t("verify.match")
        )
    )
    let installer = DependencyInstallerStub()
    let model = AppModel(
        store: ProfileStoreStub(profiles: [.officeDock]),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: diagnosticsStore,
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: eventMonitor,
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: restorePlan,
            swapPlanResult: sampleSwapPlan()
        ),
        executor: executor,
        dependencyInstaller: installer,
        verifier: verifier,
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    eventMonitor.emit(DisplayEvent(type: .reconfigured, details: "Test event"))

    await waitUntil {
        let commands = await executor.executedCommands()
        return commands == [DisplayProfile.officeDock.layout.engine.command]
            && model.diagnostics.first?.actionTaken == "auto-restore"
    }

    #expect(model.lastCommand == DisplayProfile.officeDock.layout.engine.command)
    #expect(model.diagnostics.first?.verificationResult == RestoreVerificationOutcome.success.rawValue)
    #expect(await verifier.recordedOrigins().count == 1)
}

@MainActor
@Test
func bootstrapAutoInstallsDisplayplacerWhenMissing() async {
    let executor = RestoreExecutorStub(
        dependency: .init(isAvailable: false, details: L10n.t("restoreExecutor.dependencyMissing"))
    )
    let installer = DependencyInstallerStub(
        result: .init(
            outcome: .installed,
            dependency: "displayplacer",
            location: "/opt/homebrew/bin/displayplacer",
            details: L10n.t("dependencyInstaller.installed", "/opt/homebrew/bin/displayplacer")
        ),
        onInstall: {
            await executor.setDependency(
                .init(
                    isAvailable: true,
                    location: "/opt/homebrew/bin/displayplacer",
                    details: L10n.t("restoreExecutor.availableAt", "/opt/homebrew/bin/displayplacer")
                )
            )
        }
    )

    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: AppSettingsStoreStub(),
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: executor,
        dependencyInstaller: installer,
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    await waitUntil {
        model.dependencyAvailable
            && model.dependencyLine.contains("/opt/homebrew/bin/displayplacer")
            && model.diagnostics.first?.actionTaken == "bootstrap-install"
    }

    #expect(await installer.installCallCount() == 1)
    #expect(model.dependencyAvailable == true)
    #expect(model.dependencyLine.contains("/opt/homebrew/bin/displayplacer"))
    #expect(model.diagnostics.first?.actionTaken == "bootstrap-install")
    #expect(model.diagnostics.first?.executionResult == DependencyInstallOutcome.installed.rawValue)
}

@MainActor
@Test
func automaticUpdateCheckCanSkipTheCurrentReleaseVersion() async {
    let release = AppRelease(
        tagName: "v0.2.0",
        version: "0.2.0",
        assetName: "LayoutRecall-0.2.0-macos.zip",
        downloadURL: URL(string: "https://example.com/LayoutRecall-0.2.0-macos.zip")!,
        publishedAt: nil,
        releaseNotes: "Important fixes."
    )
    let settingsStore = AppSettingsStoreStub()
    let prompt = UpdatePromptStub(response: .skipThisVersion)
    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: settingsStore,
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: DependencyInstallerStub(),
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        updateChecker: UpdateCheckerStub(release: release),
        updateInstaller: UpdateInstallerStub(),
        updatePrompt: prompt,
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    await waitUntil {
        let savedSettings = await settingsStore.latestSavedSettings()
        return model.skippedReleaseVersion == "0.2.0"
            && model.updateState == .skipped(release)
            && savedSettings?.skippedReleaseVersion == "0.2.0"
    }

    #expect(model.availableUpdate == release)
    #expect(prompt.promptedVersions() == ["0.2.0"])
}

@MainActor
@Test
func manualUpdateCheckIgnoresSkippedVersionAndShowsAvailableRelease() async {
    let release = AppRelease(
        tagName: "v0.2.0",
        version: "0.2.0",
        assetName: "LayoutRecall-0.2.0-macos.zip",
        downloadURL: URL(string: "https://example.com/LayoutRecall-0.2.0-macos.zip")!,
        publishedAt: nil,
        releaseNotes: "Important fixes."
    )
    let settingsStore = AppSettingsStoreStub(
        settings: AppSettings(
            automaticallyCheckForUpdates: true,
            skippedReleaseVersion: "0.2.0"
        )
    )
    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: settingsStore,
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: DependencyInstallerStub(),
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        updateChecker: UpdateCheckerStub(release: release),
        updateInstaller: UpdateInstallerStub(),
        updatePrompt: UpdatePromptStub(response: .later),
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()

    await waitUntil {
        model.updateState == .skipped(release)
    }

    model.checkForUpdatesNow()

    await waitUntil {
        model.updateState == .available(release)
    }

    #expect(model.availableUpdate == release)
}

@MainActor
@Test
func installingAvailableUpdateUsesInstallerAndTerminateHook() async {
    let release = AppRelease(
        tagName: "v0.2.0",
        version: "0.2.0",
        assetName: "LayoutRecall-0.2.0-macos.zip",
        downloadURL: URL(string: "https://example.com/LayoutRecall-0.2.0-macos.zip")!,
        publishedAt: nil,
        releaseNotes: nil
    )
    let installer = UpdateInstallerStub()
    let termination = TerminationRecorder()
    let settingsStore = AppSettingsStoreStub(
        settings: AppSettings(automaticallyCheckForUpdates: false)
    )
    let model = AppModel(
        store: ProfileStoreStub(),
        settingsStore: settingsStore,
        diagnosticsStore: DiagnosticsStoreStub(),
        snapshotReader: SnapshotReaderStub(displays: [.sampleLeft, .sampleRight]),
        eventMonitor: EventMonitorStub(),
        commandBuilder: StaticCommandBuilder(
            restorePlanResult: sampleRestorePlan(),
            swapPlanResult: sampleSwapPlan()
        ),
        executor: RestoreExecutorStub(),
        dependencyInstaller: DependencyInstallerStub(),
        verifier: RestoreVerifierStub(result: .skipped),
        loginItemManager: LoginItemManagerStub(),
        updateChecker: UpdateCheckerStub(release: release),
        updateInstaller: installer,
        updatePrompt: UpdatePromptStub(response: .later),
        terminateApplication: {
            termination.record()
        },
        debounceNanoseconds: 1_000_000,
        restoreCooldown: 0,
        autoBootstrap: false
    )

    await model.bootstrap()
    model.checkForUpdatesNow()

    await waitUntil {
        model.updateState == .available(release)
    }

    model.installAvailableUpdate()

    await waitUntil {
        let installedRelease = await installer.installedRelease()
        return installedRelease == release
            && termination.count() == 1
            && model.updateState == .installing(release)
    }

    #expect(await installer.replacedBundlePath() == Bundle.main.bundleURL.path)
}

private func sampleRestorePlan() -> GeneratedLayoutPlan {
    GeneratedLayoutPlan(
        command: DisplayProfile.officeDock.layout.engine.command,
        expectedOrigins: [
            DisplayOrigin(key: DisplaySnapshot.sampleLeft.preferredMatchKey, x: 0, y: 0),
            DisplayOrigin(key: DisplaySnapshot.sampleRight.preferredMatchKey, x: 2560, y: 0)
        ],
        primaryDisplayKey: DisplaySnapshot.sampleLeft.preferredMatchKey
    )
}

private func sampleSwapPlan() -> GeneratedLayoutPlan {
    GeneratedLayoutPlan(
        command: "displayplacer 'id:persistent-left enabled:true origin:(2560,0) res:2560x1440 hz:60 scaling:off' 'id:persistent-right enabled:true origin:(0,0) res:2560x1440 hz:60 scaling:off'",
        expectedOrigins: [
            DisplayOrigin(key: DisplaySnapshot.sampleLeft.preferredMatchKey, x: 2560, y: 0),
            DisplayOrigin(key: DisplaySnapshot.sampleRight.preferredMatchKey, x: 0, y: 0)
        ],
        primaryDisplayKey: DisplaySnapshot.sampleLeft.preferredMatchKey
    )
}

private func sampleShortcut(keyCode: UInt16, keyDisplay: String) -> ShortcutBinding {
    ShortcutBinding(
        keyCode: keyCode,
        modifiersRawValue: NSEvent.ModifierFlags([.command, .option]).rawValue,
        keyDisplay: keyDisplay
    )
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    pollNanoseconds: UInt64 = 20_000_000,
    _ predicate: @escaping @MainActor () async -> Bool
) async {
    let attempts = max(1, Int(timeoutNanoseconds / pollNanoseconds))

    for _ in 0..<attempts {
        if await predicate() {
            return
        }

        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    Issue.record("Timed out waiting for an asynchronous AppModel state change.")
}

private actor ProfileStoreStub: ProfileStoring {
    private var profiles: [DisplayProfile]

    init(profiles: [DisplayProfile] = []) {
        self.profiles = profiles
    }

    func loadProfiles() async throws -> [DisplayProfile] {
        profiles
    }

    func saveProfiles(_ profiles: [DisplayProfile]) async throws {
        self.profiles = profiles
    }

    func currentProfiles() -> [DisplayProfile] {
        profiles
    }
}

private actor AppSettingsStoreStub: AppSettingsStoring {
    private var settings: AppSettings
    private var savedSettings: [AppSettings] = []

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func loadSettings() async throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) async throws {
        self.settings = settings
        savedSettings.append(settings)
    }

    func latestSavedSettings() -> AppSettings? {
        savedSettings.last
    }
}

private actor ShortcutManagerStub: ShortcutManaging {
    private var latestConfiguration = ShortcutSettings()
    private var handler: (@Sendable (ShortcutAction) -> Void)?

    func configure(
        shortcuts: ShortcutSettings,
        handler: @escaping @Sendable (ShortcutAction) -> Void
    ) async throws {
        latestConfiguration = shortcuts
        self.handler = handler
    }

    func latestShortcuts() -> ShortcutSettings? {
        latestConfiguration
    }

    func trigger(_ action: ShortcutAction) async {
        handler?(action)
    }
}

private actor UpdateCheckerStub: AppUpdateChecking {
    private let release: AppRelease?

    init(release: AppRelease?) {
        self.release = release
    }

    func fetchLatestRelease() async throws -> AppRelease? {
        release
    }
}

private actor UpdateInstallerStub: AppUpdateInstalling {
    private var release: AppRelease?
    private var bundlePath: String?

    func prepareUpdateInstallation(release: AppRelease, replacing bundleURL: URL) async throws {
        self.release = release
        bundlePath = bundleURL.path
    }

    func installedRelease() -> AppRelease? {
        release
    }

    func replacedBundlePath() -> String? {
        bundlePath
    }
}

@MainActor
private final class UpdatePromptStub: AppUpdatePrompting {
    private let response: AppUpdatePromptResponse
    private var versions: [String] = []

    init(response: AppUpdatePromptResponse) {
        self.response = response
    }

    @MainActor
    func promptToInstall(release: AppRelease, currentVersion: String) async -> AppUpdatePromptResponse {
        record(version: release.versionIdentifier)
        return response
    }

    private func record(version: String) {
        versions.append(version)
    }

    func promptedVersions() -> [String] {
        versions
    }
}

@MainActor
private final class TerminationRecorder {
    private var invocations = 0

    func record() {
        invocations += 1
    }

    func count() -> Int {
        invocations
    }
}

private actor DiagnosticsStoreStub: DiagnosticsStoring {
    private var entries: [DiagnosticsEntry]

    init(entries: [DiagnosticsEntry] = []) {
        self.entries = entries
    }

    func recentEntries() async throws -> [DiagnosticsEntry] {
        entries
    }

    func append(_ entry: DiagnosticsEntry) async throws {
        entries.insert(entry, at: 0)
    }
}

private actor SnapshotReaderStub: DisplaySnapshotReading {
    private let displays: [DisplaySnapshot]

    init(displays: [DisplaySnapshot]) {
        self.displays = displays
    }

    func currentDisplays() async throws -> [DisplaySnapshot] {
        displays
    }
}

private final class EventMonitorStub: DisplayEventMonitoring {
    private(set) var startCallCount = 0
    private var handler: (@Sendable (DisplayEvent) -> Void)?

    func start(handler: @escaping @Sendable (DisplayEvent) -> Void) {
        startCallCount += 1
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func emit(_ event: DisplayEvent) {
        handler?(event)
    }
}

private struct StaticCommandBuilder: DisplayCommandBuilding, Sendable {
    let restorePlanResult: GeneratedLayoutPlan
    let swapPlanResult: GeneratedLayoutPlan

    func restorePlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan {
        restorePlanResult
    }

    func swapLeftRightPlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan {
        swapPlanResult
    }
}

private actor RestoreExecutorStub: RestoreExecuting {
    private var dependency: RestoreDependencyStatus
    private let executionResult: RestoreExecutionResult
    private var executed: [String] = []

    init(
        dependency: RestoreDependencyStatus = .init(
            isAvailable: true,
            location: "/usr/local/bin/displayplacer",
            details: L10n.t("restoreExecutor.availableAt", "/usr/local/bin/displayplacer")
        ),
        executionResult: RestoreExecutionResult = .init(
            outcome: .success,
            command: "",
            exitCode: 0,
            details: L10n.t("restoreExecutor.success")
        )
    ) {
        self.dependency = dependency
        self.executionResult = executionResult
    }

    func dependencyStatus() async -> RestoreDependencyStatus {
        dependency
    }

    func setDependency(_ dependency: RestoreDependencyStatus) {
        self.dependency = dependency
    }

    func execute(command: String) async -> RestoreExecutionResult {
        executed.append(command)

        return RestoreExecutionResult(
            outcome: executionResult.outcome,
            command: command,
            exitCode: executionResult.exitCode,
            stdout: executionResult.stdout,
            stderr: executionResult.stderr,
            duration: executionResult.duration,
            details: executionResult.details
        )
    }

    func executedCommands() -> [String] {
        executed
    }
}

private actor RestoreVerifierStub: RestoreVerifying {
    private let result: RestoreVerificationResult
    private var origins: [[DisplayOrigin]] = []

    init(result: RestoreVerificationResult) {
        self.result = result
    }

    func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult {
        origins.append(expectedOrigins)
        return result
    }

    func recordedOrigins() -> [[DisplayOrigin]] {
        origins
    }
}

private actor LoginItemManagerStub: LoginItemManaging {
    private var current: LaunchAtLoginState
    private let setResponse: LaunchAtLoginState
    private var requestedStates: [Bool] = []

    init(current: LaunchAtLoginState = .disabled, setResponse: LaunchAtLoginState = .enabled) {
        self.current = current
        self.setResponse = setResponse
    }

    func currentState() async -> LaunchAtLoginState {
        current
    }

    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        requestedStates.append(enabled)
        current = setResponse
        return setResponse
    }

    func requests() -> [Bool] {
        requestedStates
    }
}

private actor DependencyInstallerStub: DependencyInstalling {
    private let result: DependencyInstallResult
    private let onInstall: (@Sendable () async -> Void)?
    private var calls = 0

    init(
        result: DependencyInstallResult = .init(
            outcome: .alreadyInstalled,
            dependency: "displayplacer",
            location: "/usr/local/bin/displayplacer",
            details: "displayplacer is already installed at /usr/local/bin/displayplacer."
        ),
        onInstall: (@Sendable () async -> Void)? = nil
    ) {
        self.result = result
        self.onInstall = onInstall
    }

    func installDisplayplacerIfNeeded() async -> DependencyInstallResult {
        calls += 1
        await onInstall?()
        return result
    }

    func installCallCount() -> Int {
        calls
    }
}
