import AppKit
import LayoutRecallKit
import Foundation

enum MenuPrimaryState: Equatable {
    case noProfiles
    case dependencyMissing
    case manualRecovery
    case healthy
}

enum MenuStatePresentation: Equatable {
    case noProfiles
    case installing
    case dependencyMissing
    case manualRecovery
    case healthy

    var badgeText: String {
        switch self {
        case .noProfiles:
            return L10n.t("menu.state.badge.noProfiles")
        case .installing:
            return L10n.t("menu.state.badge.installing")
        case .dependencyMissing:
            return L10n.t("menu.state.badge.dependencyMissing")
        case .manualRecovery:
            return L10n.t("menu.state.badge.manualRecovery")
        case .healthy:
            return L10n.t("menu.state.badge.healthy")
        }
    }

    var systemImage: String {
        switch self {
        case .noProfiles:
            return "square.and.arrow.down"
        case .installing:
            return "hourglass"
        case .dependencyMissing:
            return "shippingbox"
        case .manualRecovery:
            return "bolt.badge.clock"
        case .healthy:
            return "checkmark.circle.fill"
        }
    }
}

enum ConfidencePresentation: Equatable {
    case high
    case needsReview
    case low

    var label: String {
        switch self {
        case .high:
            return L10n.t("confidence.high")
        case .needsReview:
            return L10n.t("confidence.review")
        case .low:
            return L10n.t("confidence.low")
        }
    }
}

enum SurfaceAction: String, CaseIterable, Identifiable {
    case installDependency
    case fixNow
    case saveNewProfile

    var id: Self { self }

    var title: String {
        switch self {
        case .installDependency:
            return L10n.t("dependency.installDisplayplacer")
        case .fixNow:
            return L10n.t("action.fixNow")
        case .saveNewProfile:
            return L10n.t("action.save")
        }
    }

    var systemImage: String {
        switch self {
        case .installDependency:
            return "arrow.down.circle.fill"
        case .fixNow:
            return "bolt.fill"
        case .saveNewProfile:
            return "square.and.arrow.down"
        }
    }
}

enum DangerousRestoreAction: String, Identifiable {
    case swapLeftRight

    var id: Self { self }

    var title: String {
        switch self {
        case .swapLeftRight:
            return L10n.t("action.swapConfirm.title")
        }
    }

    var message: String {
        switch self {
        case .swapLeftRight:
            return L10n.t("action.swapConfirm.message")
        }
    }

    var confirmationTitle: String {
        switch self {
        case .swapLeftRight:
            return L10n.t("action.swapConfirm.run")
        }
    }
}

enum SettingsPane: String, CaseIterable, Hashable, Identifiable {
    case restore
    case profiles
    case shortcuts
    case diagnostics
    case general

    var id: Self { self }

    var title: String {
        switch self {
        case .restore:
            return L10n.t("section.restore")
        case .profiles:
            return L10n.t("section.profiles")
        case .shortcuts:
            return L10n.t("section.shortcuts")
        case .diagnostics:
            return L10n.t("section.diagnostics")
        case .general:
            return L10n.t("section.general")
        }
    }

    var subtitle: String {
        switch self {
        case .restore:
            return L10n.t("settings.restore.subtitle")
        case .profiles:
            return L10n.t("settings.profiles.subtitle")
        case .shortcuts:
            return L10n.t("settings.shortcuts.subtitle")
        case .diagnostics:
            return L10n.t("settings.diagnostics.subtitle")
        case .general:
            return L10n.t("settings.general.subtitle")
        }
    }

    var systemImage: String {
        switch self {
        case .restore:
            return "sparkles.rectangle.stack"
        case .profiles:
            return "square.stack.3d.up.fill"
        case .shortcuts:
            return "command"
        case .diagnostics:
            return "stethoscope"
        case .general:
            return "gearshape"
        }
    }
}

extension AppModel {
    var menuStatePresentation: MenuStatePresentation {
        switch menuPrimaryState {
        case .noProfiles:
            return .noProfiles
        case .dependencyMissing:
            return installationInProgress ? .installing : .dependencyMissing
        case .manualRecovery:
            return .manualRecovery
        case .healthy:
            return .healthy
        }
    }

    var referenceProfile: DisplayProfile? {
        if let profileName = latestMatchedProfileName ?? latestDecision?.profileName,
           let matchedProfile = profiles.first(where: { $0.name == profileName })
        {
            return matchedProfile
        }

        return profiles.first
    }

    var currentProfileName: String? {
        referenceProfile?.name
    }

    var confidencePresentation: ConfidencePresentation? {
        guard let latestMatchScore else {
            return nil
        }

        if latestMatchScore >= 85 {
            return .high
        }

        if latestMatchScore >= 70 {
            return .needsReview
        }

        return .low
    }

    var referenceDisplays: [DisplaySnapshot] {
        (referenceProfile?.displaySet.displays ?? [])
            .sorted(by: DisplaySnapshot.positionComparator(lhs:rhs:))
    }

    var referencePrimaryDisplayKey: String? {
        referenceProfile?.layout.primaryDisplayKey
    }

    var activeDisplayCount: Int {
        if detectedDisplayCount > 0 {
            return detectedDisplayCount
        }

        return referenceProfile?.displaySet.count ?? 0
    }

    var autoRestoreBadgeText: String {
        autoRestoreEnabled
            ? L10n.t("status.badge.autoRestoreOn")
            : L10n.t("status.badge.autoRestoreOff")
    }

    var dependencyBadgeText: String {
        if installationInProgress {
            return L10n.t("status.badge.dependencyInstalling")
        }

        return dependencyAvailable
            ? L10n.t("status.badge.dependencyReady")
            : L10n.t("status.badge.dependencyMissing")
    }

    var displayBadgeText: String {
        L10n.t("status.badge.displays", activeDisplayCount)
    }

    var confidenceBadgeText: String? {
        guard let confidencePresentation else {
            return nil
        }

        return confidencePresentation.label
    }

    var activeDisplayCountLine: String {
        L10n.t("settings.profileDisplayCountCompact", activeDisplayCount)
    }

    var referenceProfileLine: String {
        guard let currentProfileName else {
            return L10n.t("settings.referenceProfileMissing")
        }

        return currentProfileName
    }

    var referenceConfidenceLine: String {
        guard let confidencePresentation else {
            return L10n.t("settings.referenceConfidenceUnavailable")
        }

        return confidencePresentation.label
    }

    var restoreModeLine: String {
        autoRestoreEnabled
            ? L10n.t("restore.automatic")
            : L10n.t("restore.manualOnly")
    }

    var menuTransitionKey: String {
        [
            String(describing: menuPrimaryState),
            currentProfileName ?? "",
            latestDiagnosticSummary ?? "",
            latestDiagnosticDetails ?? "",
            dependencyAvailable ? "1" : "0",
            installationInProgress ? "1" : "0",
            String(activeDisplayCount)
        ].joined(separator: "|")
    }

    var menuRecentActivityLine: String? {
        guard let latestEntry = diagnostics.first else {
            return nil
        }

        return L10n.t(
            "menu.recentActivity",
            latestEntry.displayTitle,
            latestEntry.timestamp.formatted(date: .abbreviated, time: .shortened)
        )
    }

    func perform(_ action: SurfaceAction) {
        switch action {
        case .installDependency:
            installDisplayplacer()
        case .fixNow:
            fixNow()
        case .saveNewProfile:
            saveCurrentLayout()
        }
    }

    func perform(_ action: DangerousRestoreAction) {
        switch action {
        case .swapLeftRight:
            swapLeftRight()
        }
    }

    var menuPrimaryState: MenuPrimaryState {
        if profiles.isEmpty {
            return .noProfiles
        }

        if installationInProgress || !dependencyAvailable {
            return .dependencyMissing
        }

        if case .autoRestore = latestDecision?.action {
            return .healthy
        }

        return .manualRecovery
    }

    var menuPrimaryAction: SurfaceAction? {
        switch menuPrimaryState {
        case .noProfiles:
            return .saveNewProfile
        case .dependencyMissing:
            return .installDependency
        case .manualRecovery:
            return .fixNow
        case .healthy:
            return nil
        }
    }

    var menuQuickActions: [SurfaceAction] {
        switch menuPrimaryState {
        case .healthy, .manualRecovery, .dependencyMissing:
            return [.saveNewProfile]
        case .noProfiles:
            return []
        }
    }

    var restorePrimaryAction: SurfaceAction? {
        menuPrimaryAction
    }

    var restoreSecondaryActions: [SurfaceAction] {
        switch menuPrimaryState {
        case .healthy, .manualRecovery, .dependencyMissing:
            return [.saveNewProfile]
        case .noProfiles:
            return []
        }
    }

    var restoreActionHint: String {
        switch menuPrimaryState {
        case .noProfiles:
            return L10n.t("settings.restore.noProfileHint")
        case .dependencyMissing:
            return installationInProgress
                ? L10n.t("settings.restore.installingHint")
                : L10n.t("settings.restore.dependencyHint")
        case .manualRecovery:
            return L10n.t("settings.restore.manualHint")
        case .healthy:
            return L10n.t("settings.restore.noImmediateAction")
        }
    }

    var dependencySummaryLine: String {
        if installationInProgress {
            return L10n.t("restore.dependency.installing")
        }

        return dependencyAvailable
            ? L10n.t("restore.dependency.ready")
            : L10n.t("restore.dependency.missing")
    }

    var canSwapDisplays: Bool {
        dependencyAvailable && !installationInProgress && detectedDisplayCount == 2
    }

    var swapAvailabilityLine: String {
        if installationInProgress {
            return L10n.t("settings.swap.installingHint")
        }

        if !dependencyAvailable {
            return L10n.t("settings.swap.dependencyHint")
        }

        if detectedDisplayCount != 2 {
            return L10n.t("runtime.swapRequiresTwo")
        }

        return L10n.t("settings.swap.ready")
    }

    var menuStatusTitle: String {
        switch menuPrimaryState {
        case .noProfiles:
            return L10n.t("menu.state.noProfiles")
        case .dependencyMissing:
            if installationInProgress {
                return L10n.t("menu.state.installingDependency")
            }

            return L10n.t("menu.state.dependencyRequired")
        case .manualRecovery:
            return L10n.t("menu.state.manualRecovery")
        case .healthy:
            if let currentProfileName {
                return L10n.t("menu.state.readyProfile", currentProfileName)
            }

            return L10n.t("menu.state.ready")
        }
    }

    var menuStatusSubtitle: String {
        switch menuPrimaryState {
        case .noProfiles:
            return L10n.t("menu.subtitle.noProfiles")
        case .dependencyMissing:
            return installationInProgress
                ? L10n.t("menu.subtitle.installingDependency")
                : L10n.t("menu.subtitle.dependencyMissing")
        case .manualRecovery:
            return L10n.t("menu.subtitle.manualRecovery")
        case .healthy:
            return L10n.t("menu.subtitle.ready")
        }
    }

    var menuMetadataLine: String {
        var components: [String] = [
            L10n.t("menu.meta.profileCount", profiles.count)
        ]

        if installationInProgress {
            components.append(L10n.t("menu.meta.dependencyInstalling"))
        } else if dependencyAvailable {
            components.append(L10n.t("menu.meta.dependencyReady"))
        } else {
            components.append(L10n.t("menu.meta.dependencyMissing"))
        }

        if let confidencePresentation {
            components.append(confidencePresentation.label)
        }

        return components.joined(separator: " · ")
    }

    func menuTitle(for action: SurfaceAction) -> String {
        switch action {
        case .installDependency:
            return installationInProgress
                ? L10n.t("dependency.installingDisplayplacer")
                : action.title
        case .fixNow:
            return action.title
        case .saveNewProfile:
            switch menuPrimaryState {
            case .noProfiles:
                return L10n.t("menu.action.saveFirstBaseline")
            case .dependencyMissing, .manualRecovery, .healthy:
                return L10n.t("menu.action.saveAnotherBaseline")
            }
        }
    }

    var appVersionDescription: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return L10n.t("settings.versionAndBuild", version, build)
        case let (version?, _):
            return L10n.t("settings.versionOnly", version)
        default:
            return L10n.t("settings.versionUnavailable")
        }
    }

    var latestDiagnosticSummary: String? {
        diagnostics.first?.outcomeSummary
    }

    var latestDiagnosticDetails: String? {
        diagnostics.first?.details
    }

    var updateStatusTitle: String {
        switch updateState {
        case .idle:
            return L10n.t("update.status.idle")
        case .checking:
            return L10n.t("update.status.checking")
        case .noPublishedReleases:
            return L10n.t("update.status.noPublishedReleases")
        case .upToDate:
            return L10n.t("update.status.upToDate")
        case .available(let release):
            return L10n.t("update.status.available", release.displayVersion)
        case .skipped(let release):
            return L10n.t("update.status.skipped", release.displayVersion)
        case .downloading(let release):
            return L10n.t("update.status.downloading", release.displayVersion)
        case .installing(let release):
            return L10n.t("update.status.installing", release.displayVersion)
        case .failed:
            return L10n.t("update.status.failed")
        }
    }

    var updateStatusDetail: String {
        switch updateState {
        case .idle:
            return automaticUpdateChecksEnabled
                ? L10n.t("update.detail.automaticEnabled")
                : L10n.t("update.detail.automaticDisabled")
        case .checking:
            return L10n.t("update.detail.checking")
        case .noPublishedReleases:
            return L10n.t("update.detail.noPublishedReleases")
        case .upToDate:
            return L10n.t("update.detail.upToDate")
        case .available(let release):
            if let publishedAt = release.publishedAt {
                return L10n.t(
                    "update.detail.availableWithDate",
                    release.displayVersion,
                    publishedAt.formatted(date: .abbreviated, time: .omitted)
                )
            }

            return L10n.t("update.detail.available", release.displayVersion)
        case .skipped(let release):
            return L10n.t("update.detail.skipped", release.displayVersion)
        case .downloading:
            return L10n.t("update.detail.downloading")
        case .installing:
            return L10n.t("update.detail.installing")
        case .failed(let message):
            return message
        }
    }

    var canInstallAvailableUpdate: Bool {
        availableUpdate != nil && !updateState.isBusy
    }
}
