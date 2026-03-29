import Combine
import LayoutRecallKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profiles: [DisplayProfile] = []
    @Published private(set) var diagnostics: [DiagnosticsEntry] = []
    @Published private(set) var statusLine = "Starting LayoutRecall."
    @Published private(set) var decisionLine = "Waiting for a saved profile."
    @Published private(set) var dependencyLine = "Checking displayplacer availability."
    @Published private(set) var dependencyAvailable = false
    @Published private(set) var installationInProgress = false
    @Published private(set) var loginItemLine = "Checking launch at login status."
    @Published private(set) var lastCommand = ""
    @Published var autoRestoreEnabled = true
    @Published var launchAtLoginEnabled = false
    @Published private(set) var shortcuts = ShortcutSettings()

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
    private let debounceNanoseconds: UInt64
    private let restoreCooldown: TimeInterval

    private var debounceTask: Task<Void, Never>?
    private var restoreCooldownUntil: Date?
    private var installationTask: Task<Void, Never>?
    private var automaticInstallAttempted = false

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
            trigger: DisplayEvent(type: .manual, details: "Application bootstrap completed."),
            allowAutomaticRestore: false,
            shouldRecordDecision: false
        )
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
                trigger: DisplayEvent(type: .manual, details: "Auto restore preference changed."),
                allowAutomaticRestore: false,
                shouldRecordDecision: false
            )
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginEnabled = enabled

        Task {
            do {
                try await settingsStore.saveSettings(
                    AppSettings(
                        launchAtLogin: enabled,
                        shortcuts: shortcuts
                    )
                )
                let state = try await loginItemManager.setEnabled(enabled)
                await MainActor.run {
                    self.loginItemLine = state.description
                    self.statusLine = enabled
                        ? "Launch at login preference saved."
                        : "Launch at login preference cleared."
                }
            } catch {
                await MainActor.run {
                    self.loginItemLine = "Launch at login could not be updated."
                    self.statusLine = "Failed to update launch at login: \(error.localizedDescription)"
                }
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
                trigger: DisplayEvent(type: .manual, details: "Confidence threshold changed."),
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
            statusLine = "Ignoring \(event.type.rawValue) during restore cooldown."
            return
        }

        statusLine = "Detected a \(event.type.rawValue) event. Waiting for displays to settle."
        decisionLine = event.details ?? "Preparing to evaluate the current display layout."

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

            if let match {
                decisionLine = "\(decision.reason) Score: \(match.score)."
            } else {
                decisionLine = decision.reason
            }

            statusLine = "Detected \(currentDisplays.count) connected display\(currentDisplays.count == 1 ? "" : "s")."

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
            statusLine = "Failed to read the current display set."
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
                statusLine = dependency.details
                decisionLine = "displayplacer is required before manual restore can run."
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

            guard let match = coordinator.matcher.bestMatch(for: currentDisplays, among: profiles) else {
                statusLine = "No compatible saved profile was found."
                decisionLine = "Save a profile before trying manual restore."
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

            await executeRestore(
                command: match.profile.layout.engine.command,
                expectedOrigins: match.profile.layout.expectedOrigins,
                trigger: DisplayEventType.manual.rawValue,
                actionTaken: "manual-fix",
                profileName: match.profile.name,
                score: match.score,
                details: "User requested manual restore."
            )
        } catch {
            statusLine = "Failed to read the current display set for manual restore."
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
                name: "Workspace \(nextIndex)",
                displays: currentDisplays,
                layoutPlan: layoutPlan
            )

            profiles.append(profile)
            autoRestoreEnabled = profiles.allSatisfy(\.settings.autoRestore)
            lastCommand = profile.layout.engine.command

            await persistProfiles()

            statusLine = "Captured the current layout as \(profile.name)."
            decisionLine = "The saved profile is ready for future display restore events."

            await recordDiagnostic(
                eventType: DisplayEventType.manual.rawValue,
                profileName: profile.name,
                score: nil,
                actionTaken: "save-profile",
                executionResult: RestoreVerificationOutcome.skipped.rawValue,
                verificationResult: RestoreVerificationOutcome.skipped.rawValue,
                details: "Saved the current live display layout as a profile."
            )
        } catch {
            statusLine = "Failed to capture the current layout."
            decisionLine = error.localizedDescription
        }
    }

    private func performSwapLeftRight() async {
        do {
            let currentDisplays = try await snapshotReader.currentDisplays()
            let layoutPlan = try commandBuilder.swapLeftRightPlan(for: currentDisplays)

            await executeRestore(
                command: layoutPlan.command,
                expectedOrigins: layoutPlan.expectedOrigins,
                trigger: DisplayEventType.manual.rawValue,
                actionTaken: "swap-left-right",
                profileName: nil,
                score: nil,
                details: "User requested the current two displays be swapped."
            )
        } catch {
            statusLine = "Swap Left / Right is unavailable."
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
        statusLine = "Running restore command."
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
            statusLine = "Failed to load saved profiles."
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
            statusLine = "Failed to load diagnostics history."
            decisionLine = error.localizedDescription
        }
    }

    private func loadSettings() async {
        do {
            let settings = try await settingsStore.loadSettings()
            launchAtLoginEnabled = settings.launchAtLogin
            shortcuts = settings.shortcuts
        } catch {
            statusLine = "Failed to load app settings."
            decisionLine = error.localizedDescription
        }
    }

    private func persistProfiles() async {
        do {
            try await store.saveProfiles(profiles)
        } catch {
            statusLine = "Failed to save profiles."
            decisionLine = error.localizedDescription
        }
    }

    private func persistSettings() async {
        do {
            try await settingsStore.saveSettings(
                AppSettings(
                    launchAtLogin: launchAtLoginEnabled,
                    shortcuts: shortcuts
                )
            )
        } catch {
            statusLine = "Failed to save app settings."
            decisionLine = error.localizedDescription
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
            statusLine = "Failed to configure keyboard shortcuts."
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
        statusLine = automatic ? "Installing displayplacer automatically." : "Installing displayplacer."
        decisionLine = automatic
            ? "LayoutRecall is setting up its restore dependency in the background."
            : "LayoutRecall is trying to install displayplacer now."

        let result = await dependencyInstaller.installDisplayplacerIfNeeded()
        installationInProgress = false

        let dependency = await executor.dependencyStatus()
        dependencyAvailable = dependency.isAvailable
        dependencyLine = dependency.details
        statusLine = result.details

        if result.outcome == .installed || result.outcome == .alreadyInstalled {
            decisionLine = automatic
                ? "displayplacer is ready for future restore events."
                : "displayplacer is ready. Retry the action or wait for the next restore event."
        } else {
            decisionLine = automatic
                ? "Automatic dependency setup failed. Open Settings to inspect the status."
                : "displayplacer could not be installed automatically."
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
            statusLine = "Failed to save diagnostics."
            decisionLine = error.localizedDescription
        }
    }
}
