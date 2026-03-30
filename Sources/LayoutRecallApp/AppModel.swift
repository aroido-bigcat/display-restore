import AppKit
import Combine
import LayoutRecallKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profiles: [DisplayProfile] = []
    @Published private(set) var diagnostics: [DiagnosticsEntry] = []
    @Published private(set) var statusLine = L10n.t("status.starting")
    @Published private(set) var decisionLine = L10n.t("status.waitingSavedProfile")
    @Published private(set) var dependencyLine = L10n.t("status.checkingDependency")
    @Published private(set) var dependencyAvailable = false
    @Published private(set) var installationInProgress = false
    @Published private(set) var loginItemLine = L10n.t("status.checkingLoginItem")
    @Published private(set) var lastCommand = ""
    @Published private(set) var detectedDisplayCount = 0
    @Published private(set) var latestDecision: RestoreDecision?
    @Published private(set) var latestMatchedProfileName: String?
    @Published private(set) var latestMatchScore: Int?
    @Published private(set) var updateState: AppUpdateState = .idle
    @Published private(set) var availableUpdate: AppRelease?
    @Published var automaticUpdateChecksEnabled = true
    @Published var autoRestoreEnabled = true
    @Published var launchAtLoginEnabled = false
    @Published private(set) var shortcuts = ShortcutSettings()
    @Published private(set) var skippedReleaseVersion: String?

    private let store: any ProfileStoring
    private let settingsStore: any AppSettingsStoring
    private let diagnosticsStore: any DiagnosticsStoring
    private let snapshotReader: any DisplaySnapshotReading
    private let eventMonitor: any DisplayEventMonitoring
    private let commandBuilder: any DisplayCommandBuilding
    private let coordinator: RestoreCoordinator
    private let executor: any RestoreExecuting
    private let dependencyInstaller: any DependencyInstalling
    private let verifier: any RestoreVerifying
    private let loginItemManager: any LoginItemManaging
    private let shortcutManager: any ShortcutManaging
    private let updateChecker: any AppUpdateChecking
    private let updateInstaller: any AppUpdateInstalling
    private let updatePrompt: any AppUpdatePrompting
    private let terminateApplication: @MainActor () -> Void
    private let debounceNanoseconds: UInt64
    private let restoreCooldown: TimeInterval

    private var debounceTask: Task<Void, Never>?
    private var restoreCooldownUntil: Date?
    private var installationTask: Task<Void, Never>?
    private var automaticInstallAttempted = false
    private var promptedUpdateVersion: String?

    init(
        store: any ProfileStoring = ProfileStore(),
        settingsStore: any AppSettingsStoring = AppSettingsStore(),
        diagnosticsStore: any DiagnosticsStoring = DiagnosticsLogger(),
        snapshotReader: any DisplaySnapshotReading = DisplaySnapshotReader(),
        eventMonitor: any DisplayEventMonitoring = CGDisplayEventMonitor(),
        commandBuilder: any DisplayCommandBuilding = DisplayplacerCommandBuilder(),
        coordinator: RestoreCoordinator = RestoreCoordinator(),
        executor: any RestoreExecuting = DisplayplacerRestoreExecutor(),
        dependencyInstaller: any DependencyInstalling = DisplayplacerInstaller(),
        verifier: any RestoreVerifying = RestoreVerifier(),
        loginItemManager: any LoginItemManaging = AppLoginItemManager(),
        shortcutManager: any ShortcutManaging = GlobalHotKeyManager(),
        updateChecker: any AppUpdateChecking = NoopAppUpdateChecker(),
        updateInstaller: any AppUpdateInstalling = NoopAppUpdateInstaller(),
        updatePrompt: any AppUpdatePrompting = NoopAppUpdatePrompt(),
        terminateApplication: @escaping @MainActor () -> Void = { NSApp.terminate(nil) },
        debounceNanoseconds: UInt64 = 2_000_000_000,
        restoreCooldown: TimeInterval = 8,
        autoBootstrap: Bool = true
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.diagnosticsStore = diagnosticsStore
        self.snapshotReader = snapshotReader
        self.eventMonitor = eventMonitor
        self.commandBuilder = commandBuilder
        self.coordinator = coordinator
        self.executor = executor
        self.dependencyInstaller = dependencyInstaller
        self.verifier = verifier
        self.loginItemManager = loginItemManager
        self.shortcutManager = shortcutManager
        self.updateChecker = updateChecker
        self.updateInstaller = updateInstaller
        self.updatePrompt = updatePrompt
        self.terminateApplication = terminateApplication
        self.debounceNanoseconds = debounceNanoseconds
        self.restoreCooldown = restoreCooldown

        if autoBootstrap {
            Task {
                await bootstrap()
            }
        }
    }

    func bootstrap() async {
        await loadProfiles()
        await loadDiagnostics()
        await loadSettings()
        await configureShortcuts()
        await refreshDependencyState()
        await refreshLoginItemState()
        startMonitoring()
        await refreshCurrentState(
            trigger: DisplayEvent(type: .manual, details: L10n.t("event.bootstrapCompleted")),
            allowAutomaticRestore: false,
            shouldRecordDecision: false
        )

        if automaticUpdateChecksEnabled {
            Task { @MainActor [weak self] in
                await self?.checkForUpdates(userInitiated: false, promptIfAvailable: true)
            }
        }
    }

    func fixNow() {
        Task {
            await performManualRestore()
        }
    }

    func saveCurrentLayout() {
        Task {
            await performSaveCurrentLayout()
        }
    }

    func installDisplayplacer() {
        Task {
            await installDependency(trigger: "manual-install", automatic: false)
        }
    }

    func swapLeftRight() {
        Task {
            await performSwapLeftRight()
        }
    }

    func checkForUpdatesNow() {
        Task {
            await checkForUpdates(userInitiated: true, promptIfAvailable: false)
        }
    }

    func installAvailableUpdate() {
        guard let availableUpdate else {
            return
        }

        Task {
            await installUpdate(availableUpdate)
        }
    }

    func skipAvailableUpdateVersion() {
        guard let availableUpdate else {
            return
        }

        Task {
            await markSkippedRelease(availableUpdate)
        }
    }

    func clearSkippedUpdateVersion() {
        skippedReleaseVersion = nil

        Task {
            await persistSettings()
        }
    }

    func shortcutBinding(for action: ShortcutAction) -> ShortcutBinding? {
        shortcuts[action]
    }

    func setShortcut(_ binding: ShortcutBinding?, for action: ShortcutAction) {
        if let binding {
            for candidate in ShortcutAction.allCases where candidate != action && shortcuts[candidate] == binding {
                shortcuts[candidate] = nil
            }
        }

        shortcuts[action] = binding

        Task {
            await persistSettings()
            await configureShortcuts()
        }
    }

    func setAutoRestore(_ enabled: Bool) {
        autoRestoreEnabled = enabled

        guard !profiles.isEmpty else {
            return
        }

        profiles = profiles.map { profile in
            var updated = profile
            updated.settings.autoRestore = enabled
            return updated
        }

        Task {
            await persistProfiles()
            await refreshCurrentState(
                trigger: DisplayEvent(type: .manual, details: L10n.t("event.autoRestorePreferenceChanged")),
                allowAutomaticRestore: false,
                shouldRecordDecision: false
            )
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginEnabled = enabled

        Task {
            do {
                try await settingsStore.saveSettings(currentSettings())
                let state = try await loginItemManager.setEnabled(enabled)
                await MainActor.run {
                    self.loginItemLine = state.description
                    self.statusLine = enabled
                        ? L10n.t("status.launchAtLoginSaved")
                        : L10n.t("status.launchAtLoginCleared")
                }
            } catch {
                await MainActor.run {
                    self.loginItemLine = L10n.t("status.launchAtLoginUpdateFailed")
                    self.statusLine = L10n.t("status.failedUpdateLaunchAtLogin", error.localizedDescription)
                }
            }
        }
    }

    func setAutomaticUpdateChecks(_ enabled: Bool) {
        automaticUpdateChecksEnabled = enabled

        if !enabled {
            updateState = .idle
        }

        Task {
            await persistSettings()

            if enabled {
                await checkForUpdates(userInitiated: false, promptIfAvailable: false)
            }
        }
    }

    func renameProfile(_ profileID: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }

        profiles[index].name = name

        Task {
            await persistProfiles()
        }
    }

    func setConfidenceThreshold(_ profileID: UUID, to threshold: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }

        profiles[index].settings.confidenceThreshold = threshold

        Task {
            await persistProfiles()
            await refreshCurrentState(
                trigger: DisplayEvent(type: .manual, details: L10n.t("event.confidenceThresholdChanged")),
                allowAutomaticRestore: false,
                shouldRecordDecision: false
            )
        }
    }

    func setProfileAutoRestore(_ profileID: UUID, to enabled: Bool) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }

        profiles[index].settings.autoRestore = enabled
        autoRestoreEnabled = profiles.isEmpty ? true : profiles.allSatisfy(\.settings.autoRestore)

        Task {
            await persistProfiles()
            await refreshCurrentState(
                trigger: DisplayEvent(type: .manual, details: L10n.t("event.autoRestorePreferenceChanged")),
                allowAutomaticRestore: false,
                shouldRecordDecision: false
            )
        }
    }

    private func startMonitoring() {
        eventMonitor.start { [weak self] event in
            Task { @MainActor in
                self?.handleDisplayEvent(event)
            }
        }
    }

    private func handleDisplayEvent(_ event: DisplayEvent) {
        if let restoreCooldownUntil, restoreCooldownUntil > Date() {
            statusLine = L10n.t("status.ignoringEventCooldown", L10n.eventTypeName(event.type.rawValue))
            return
        }

        statusLine = L10n.t("status.detectedEvent", L10n.eventTypeName(event.type.rawValue))
        decisionLine = event.details ?? L10n.t("status.preparingCurrentLayout")

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanoseconds ?? 0)
            await self?.refreshCurrentState(trigger: event, allowAutomaticRestore: true, shouldRecordDecision: true)
        }
    }

    private func refreshCurrentState(
        trigger: DisplayEvent,
        allowAutomaticRestore: Bool,
        shouldRecordDecision: Bool
    ) async {
        let dependency = await refreshDependencyState()

        do {
            let currentDisplays = try await snapshotReader.currentDisplays()
            let match = coordinator.matcher.bestMatch(for: currentDisplays, among: profiles)
            let decision = coordinator.decide(
                for: currentDisplays,
                profiles: profiles,
                dependencyAvailable: dependency.isAvailable
            )

            lastCommand = {
                if case .autoRestore(let command) = decision.action {
                    return command
                }
                return match?.profile.layout.engine.command ?? ""
            }()

            detectedDisplayCount = currentDisplays.count
            latestDecision = decision
            latestMatchedProfileName = match?.profile.name
            latestMatchScore = match?.score
            decisionLine = decision.reason
            statusLine = L10n.connectedDisplayCount(currentDisplays.count)

            if allowAutomaticRestore,
               case .autoRestore(let command) = decision.action,
               let match
            {
                await executeRestore(
                    command: command,
                    expectedOrigins: match.profile.layout.expectedOrigins,
                    trigger: trigger.type.rawValue,
                    actionTaken: "auto-restore",
                    profileName: match.profile.name,
                    score: match.score,
                    details: decision.reason
                )
                return
            }

            if shouldRecordDecision {
                await recordDiagnostic(
                    eventType: trigger.type.rawValue,
                    profileName: match?.profile.name,
                    score: match?.score,
                    actionTaken: decisionActionLabel(decision.action),
                    executionResult: dependency.isAvailable
                        ? RestoreVerificationOutcome.skipped.rawValue
                        : RestoreExecutionOutcome.dependencyMissing.rawValue,
                    verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                    details: decision.reason
                )
            }
        } catch {
            lastCommand = ""
            detectedDisplayCount = 0
            latestDecision = nil
            latestMatchedProfileName = nil
            latestMatchScore = nil
            statusLine = L10n.t("status.failedReadCurrentDisplaySet")
            decisionLine = error.localizedDescription

            if shouldRecordDecision {
                await recordDiagnostic(
                    eventType: trigger.type.rawValue,
                    profileName: nil,
                    score: nil,
                    actionTaken: "snapshot-read",
                    executionResult: RestoreVerificationOutcome.skipped.rawValue,
                    verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                    details: error.localizedDescription
                )
            }
        }
    }

    private func performManualRestore() async {
        let dependency = await refreshDependencyState()
        guard dependency.isAvailable else {
            let result = await installDependency(trigger: "manual-install", automatic: false)

            guard result.outcome == .installed || result.outcome == .alreadyInstalled else {
                latestDecision = RestoreDecision(
                    action: .offerManualFix,
                    reason: L10n.t("decision.manualRestoreRequiresDependency")
                )
                latestMatchedProfileName = nil
                latestMatchScore = nil
                statusLine = dependency.details
                decisionLine = L10n.t("decision.manualRestoreRequiresDependency")
                await recordDiagnostic(
                    eventType: DisplayEventType.manual.rawValue,
                    profileName: nil,
                    score: nil,
                    actionTaken: "manual-fix",
                    executionResult: RestoreExecutionOutcome.dependencyMissing.rawValue,
                    verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                    details: dependency.details
                )
                return
            }

            await performManualRestore()
            return
        }

        do {
            let currentDisplays = try await snapshotReader.currentDisplays()
            detectedDisplayCount = currentDisplays.count

            guard let match = coordinator.matcher.bestMatch(for: currentDisplays, among: profiles) else {
                latestDecision = RestoreDecision(
                    action: .offerManualFix,
                    reason: L10n.t("decision.saveProfileBeforeManualRestore")
                )
                latestMatchedProfileName = nil
                latestMatchScore = nil
                statusLine = L10n.t("status.noCompatibleSavedProfile")
                decisionLine = L10n.t("decision.saveProfileBeforeManualRestore")
                await recordDiagnostic(
                    eventType: DisplayEventType.manual.rawValue,
                    profileName: nil,
                    score: nil,
                    actionTaken: "manual-fix",
                    executionResult: RestoreVerificationOutcome.skipped.rawValue,
                    verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                    details: LayoutRecallRuntimeError.noCompatibleProfile.localizedDescription
                )
                return
            }

            latestDecision = RestoreDecision(
                action: .offerManualFix,
                profileName: match.profile.name,
                score: match.score,
                reason: L10n.t("details.userRequestedManualRestore")
            )
            latestMatchedProfileName = match.profile.name
            latestMatchScore = match.score
            await executeRestore(
                command: match.profile.layout.engine.command,
                expectedOrigins: match.profile.layout.expectedOrigins,
                trigger: DisplayEventType.manual.rawValue,
                actionTaken: "manual-fix",
                profileName: match.profile.name,
                score: match.score,
                details: L10n.t("details.userRequestedManualRestore")
            )
        } catch {
            latestDecision = nil
            latestMatchedProfileName = nil
            latestMatchScore = nil
            statusLine = L10n.t("status.failedReadCurrentDisplaySetManual")
            decisionLine = error.localizedDescription
            await recordDiagnostic(
                eventType: DisplayEventType.manual.rawValue,
                profileName: nil,
                score: nil,
                actionTaken: "manual-fix",
                executionResult: RestoreVerificationOutcome.skipped.rawValue,
                verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                details: error.localizedDescription
            )
        }
    }

    private func performSaveCurrentLayout() async {
        do {
            let currentDisplays = try await snapshotReader.currentDisplays()
            let layoutPlan = try commandBuilder.restorePlan(for: currentDisplays)
            let nextIndex = profiles.count + 1
            let profile = DisplayProfile.draft(
                name: L10n.workspaceName(nextIndex),
                displays: currentDisplays,
                layoutPlan: layoutPlan
            )

            profiles.append(profile)
            autoRestoreEnabled = profiles.allSatisfy(\.settings.autoRestore)
            detectedDisplayCount = currentDisplays.count
            latestDecision = RestoreDecision(
                action: .autoRestore(command: profile.layout.engine.command),
                profileName: profile.name,
                reason: L10n.t("decision.savedProfileReady")
            )
            latestMatchedProfileName = profile.name
            latestMatchScore = nil
            lastCommand = profile.layout.engine.command

            await persistProfiles()

            statusLine = L10n.t("status.capturedLayout", profile.name)
            decisionLine = L10n.t("decision.savedProfileReady")

            await recordDiagnostic(
                eventType: DisplayEventType.manual.rawValue,
                profileName: profile.name,
                score: nil,
                actionTaken: "save-profile",
                executionResult: RestoreVerificationOutcome.skipped.rawValue,
                verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                details: L10n.t("details.savedCurrentLayout")
            )
        } catch {
            statusLine = L10n.t("status.failedCaptureLayout")
            decisionLine = error.localizedDescription
        }
    }

    private func performSwapLeftRight() async {
        do {
            let currentDisplays = try await snapshotReader.currentDisplays()
            let layoutPlan = try commandBuilder.swapLeftRightPlan(for: currentDisplays)
            detectedDisplayCount = currentDisplays.count
            latestDecision = RestoreDecision(
                action: .offerManualFix,
                reason: L10n.t("details.userRequestedSwap")
            )
            latestMatchedProfileName = nil
            latestMatchScore = nil

            await executeRestore(
                command: layoutPlan.command,
                expectedOrigins: layoutPlan.expectedOrigins,
                trigger: DisplayEventType.manual.rawValue,
                actionTaken: "swap-left-right",
                profileName: nil,
                score: nil,
                details: L10n.t("details.userRequestedSwap")
            )
        } catch {
            latestDecision = nil
            latestMatchedProfileName = nil
            latestMatchScore = nil
            statusLine = L10n.t("status.swapUnavailable")
            decisionLine = error.localizedDescription
            await recordDiagnostic(
                eventType: DisplayEventType.manual.rawValue,
                profileName: nil,
                score: nil,
                actionTaken: "swap-left-right",
                executionResult: RestoreVerificationOutcome.skipped.rawValue,
                verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                details: error.localizedDescription
            )
        }
    }

    private func executeRestore(
        command: String,
        expectedOrigins: [DisplayOrigin],
        trigger: String,
        actionTaken: String,
        profileName: String?,
        score: Int?,
        details: String
    ) async {
        lastCommand = command
        statusLine = L10n.t("status.runningRestoreCommand")
        decisionLine = details

        let executionResult = await executor.execute(command: command)
        var verificationResult = RestoreVerificationResult.skipped

        if executionResult.outcome != .dependencyMissing {
            restoreCooldownUntil = Date().addingTimeInterval(restoreCooldown)
        }

        if executionResult.outcome == .success {
            verificationResult = await verifier.verify(expectedOrigins: expectedOrigins, using: snapshotReader)
        }

        let executionSummary = executionResult.outcome.rawValue
        let verificationSummary = verificationResult.outcome.rawValue
        if executionResult.outcome == .success {
            latestDecision = RestoreDecision(
                action: .autoRestore(command: command),
                profileName: profileName,
                score: score,
                reason: verificationResult.details
            )
        } else {
            latestDecision = RestoreDecision(
                action: .offerManualFix,
                profileName: profileName,
                score: score,
                reason: executionResult.details
            )
        }
        latestMatchedProfileName = profileName
        latestMatchScore = score
        statusLine = executionResult.details
        decisionLine = verificationResult.details

        await recordDiagnostic(
            eventType: trigger,
            profileName: profileName,
            score: score,
            actionTaken: actionTaken,
            executionResult: executionSummary,
            verificationResult: verificationSummary,
            details: [
                details,
                executionResult.details,
                verificationResult.details
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        )
    }

    private func decisionActionLabel(_ action: RestoreAction) -> String {
        switch action {
        case .autoRestore:
            return "auto-restore"
        case .offerManualFix:
            return "manual-recovery"
        case .saveNewProfile:
            return "save-new-profile"
        case .idle:
            return "idle"
        }
    }

    private func loadProfiles() async {
        do {
            let storedProfiles = try await store.loadProfiles()
            let normalizedProfiles = normalizeProfiles(storedProfiles)
            profiles = normalizedProfiles
            autoRestoreEnabled = profiles.isEmpty ? true : profiles.allSatisfy(\.settings.autoRestore)

            if normalizedProfiles != storedProfiles {
                try await store.saveProfiles(normalizedProfiles)
            }
        } catch {
            statusLine = L10n.t("status.failedLoadProfiles")
            decisionLine = error.localizedDescription
        }
    }

    private func normalizeProfiles(_ storedProfiles: [DisplayProfile]) -> [DisplayProfile] {
        storedProfiles.map { profile in
            guard let updatedPlan = try? commandBuilder.restorePlan(for: profile.displaySet.displays) else {
                return profile
            }

            var normalized = profile
            normalized.layout = LayoutDefinition(
                primaryDisplayKey: updatedPlan.primaryDisplayKey,
                expectedOrigins: updatedPlan.expectedOrigins,
                engine: LayoutEngineCommand(
                    type: profile.layout.engine.type,
                    command: updatedPlan.command
                )
            )
            return normalized
        }
    }

    private func loadDiagnostics() async {
        do {
            diagnostics = try await diagnosticsStore.recentEntries()
        } catch {
            statusLine = L10n.t("status.failedLoadDiagnostics")
            decisionLine = error.localizedDescription
        }
    }

    private func loadSettings() async {
        do {
            let settings = try await settingsStore.loadSettings()
            launchAtLoginEnabled = settings.launchAtLogin
            shortcuts = settings.shortcuts
            automaticUpdateChecksEnabled = settings.automaticallyCheckForUpdates
            skippedReleaseVersion = settings.skippedReleaseVersion
        } catch {
            statusLine = L10n.t("status.failedLoadSettings")
            decisionLine = error.localizedDescription
        }
    }

    private func persistProfiles() async {
        do {
            try await store.saveProfiles(profiles)
        } catch {
            statusLine = L10n.t("status.failedSaveProfiles")
            decisionLine = error.localizedDescription
        }
    }

    private func persistSettings() async {
        do {
            try await settingsStore.saveSettings(currentSettings())
        } catch {
            statusLine = L10n.t("status.failedSaveSettings")
            decisionLine = error.localizedDescription
        }
    }

    private func currentSettings() -> AppSettings {
        AppSettings(
            launchAtLogin: launchAtLoginEnabled,
            shortcuts: shortcuts,
            automaticallyCheckForUpdates: automaticUpdateChecksEnabled,
            skippedReleaseVersion: skippedReleaseVersion
        )
    }

    private func checkForUpdates(userInitiated: Bool, promptIfAvailable: Bool) async {
        guard !updateState.isBusy else {
            return
        }

        updateState = .checking

        do {
            guard let release = try await updateChecker.fetchLatestRelease() else {
                availableUpdate = nil
                updateState = .noPublishedReleases
                return
            }

            guard AppVersionComparator.isNewer(release.versionIdentifier, than: AppRuntimeMetadata.currentVersion) else {
                availableUpdate = nil
                updateState = .upToDate
                return
            }

            availableUpdate = release

            if !userInitiated, skippedReleaseVersion == release.versionIdentifier {
                updateState = .skipped(release)
                return
            }

            updateState = .available(release)

            guard promptIfAvailable,
                  promptedUpdateVersion != release.versionIdentifier else {
                return
            }

            promptedUpdateVersion = release.versionIdentifier

            let promptResponse = await updatePrompt.promptToInstall(
                release: release,
                currentVersion: AppRuntimeMetadata.currentVersion
            )

            switch promptResponse {
            case .install:
                await installUpdate(release)
            case .skipThisVersion:
                await markSkippedRelease(release)
            case .later:
                updateState = .available(release)
            }
        } catch let error as AppUpdateError {
            availableUpdate = nil
            updateState = error == .noPublishedReleases
                ? .noPublishedReleases
                : .failed(error.localizedDescription)
        } catch {
            availableUpdate = nil
            updateState = .failed(error.localizedDescription)
        }
    }

    private func markSkippedRelease(_ release: AppRelease) async {
        skippedReleaseVersion = release.versionIdentifier
        availableUpdate = release
        updateState = .skipped(release)
        await persistSettings()
    }

    private func installUpdate(_ release: AppRelease) async {
        updateState = .downloading(release)

        do {
            try await updateInstaller.prepareUpdateInstallation(
                release: release,
                replacing: Bundle.main.bundleURL
            )
            updateState = .installing(release)
            terminateApplication()
        } catch {
            availableUpdate = release
            updateState = .failed(error.localizedDescription)
        }
    }

    private func configureShortcuts() async {
        do {
            try await shortcutManager.configure(shortcuts: shortcuts) { [weak self] action in
                Task { @MainActor in
                    await self?.handleShortcut(action)
                }
            }
        } catch {
            statusLine = L10n.t("status.failedConfigureShortcuts")
            decisionLine = error.localizedDescription
        }
    }

    private func handleShortcut(_ action: ShortcutAction) async {
        switch action {
        case .fixNow:
            await performManualRestore()
        case .saveCurrentLayout:
            await performSaveCurrentLayout()
        case .swapLeftRight:
            await performSwapLeftRight()
        }
    }

    @discardableResult
    private func refreshDependencyState() async -> RestoreDependencyStatus {
        let dependency = await executor.dependencyStatus()
        dependencyAvailable = dependency.isAvailable
        dependencyLine = dependency.details

        if !dependency.isAvailable, !automaticInstallAttempted {
            automaticInstallAttempted = true
            installationTask = Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                _ = await self.runDependencyInstall(trigger: "bootstrap-install", automatic: true)
                self.installationTask = nil
            }
        }

        return dependency
    }

    @discardableResult
    private func installDependency(trigger: String, automatic: Bool) async -> DependencyInstallResult {
        if let installationTask {
            await installationTask.value
            let dependency = await executor.dependencyStatus()
            return DependencyInstallResult(
                outcome: dependency.isAvailable ? .alreadyInstalled : .failed,
                dependency: "displayplacer",
                location: dependency.location,
                details: dependency.details
            )
        }

        return await runDependencyInstall(trigger: trigger, automatic: automatic)
    }

    @discardableResult
    private func runDependencyInstall(trigger: String, automatic: Bool) async -> DependencyInstallResult {
        installationInProgress = true
        statusLine = automatic ? L10n.t("status.installingDisplayplacerAuto") : L10n.t("status.installingDisplayplacer")
        decisionLine = automatic
            ? L10n.t("decision.backgroundDependencySetup")
            : L10n.t("decision.tryingInstallDependency")

        let result = await dependencyInstaller.installDisplayplacerIfNeeded()
        installationInProgress = false

        let dependency = await executor.dependencyStatus()
        dependencyAvailable = dependency.isAvailable
        dependencyLine = dependency.details
        statusLine = result.details

        if result.outcome == .installed || result.outcome == .alreadyInstalled {
            decisionLine = automatic
                ? L10n.t("decision.dependencyReadyAuto")
                : L10n.t("decision.dependencyReadyManual")
        } else {
            decisionLine = automatic
                ? L10n.t("decision.dependencySetupFailedAuto")
                : L10n.t("decision.dependencyInstallFailed")
        }

        await recordDiagnostic(
            eventType: DisplayEventType.manual.rawValue,
            profileName: nil,
            score: nil,
            actionTaken: trigger,
            executionResult: result.outcome.rawValue,
            verificationResult: RestoreVerificationOutcome.skipped.rawValue,
            details: result.details
        )

        return result
    }

    private func refreshLoginItemState() async {
        let loginState = await loginItemManager.currentState()
        loginItemLine = loginState.description
    }

    private func recordDiagnostic(
        eventType: String,
        profileName: String?,
        score: Int?,
        actionTaken: String,
        executionResult: String,
        verificationResult: String,
        details: String
    ) async {
        let entry = DiagnosticsEntry(
            eventType: eventType,
            profileName: profileName,
            score: score,
            actionTaken: actionTaken,
            executionResult: executionResult,
            verificationResult: verificationResult,
            details: details
        )

        do {
            try await diagnosticsStore.append(entry)
            diagnostics = try await diagnosticsStore.recentEntries()
        } catch {
            statusLine = L10n.t("status.failedSaveDiagnostics")
            decisionLine = error.localizedDescription
        }
    }
}
