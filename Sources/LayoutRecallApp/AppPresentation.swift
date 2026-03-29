import AppKit
import LayoutRecallKit
import Foundation

enum MenuPrimaryState: Equatable {
    case noProfiles
    case dependencyMissing
    case manualRecovery
    case healthy
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
    var currentProfileName: String? {
        latestMatchedProfileName ?? profiles.first?.name
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

    var menuStatusTitle: String {
        switch menuPrimaryState {
        case .noProfiles:
            return L10n.t("restoreDecision.noSavedProfile")
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
            return L10n.t("profiles.empty")
        case .dependencyMissing:
            return dependencyLine
        case .manualRecovery:
            return latestDecision?.reason ?? decisionLine
        case .healthy:
            return latestDecision?.reason ?? L10n.t("restoreDecision.confidentMatch")
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

    var restorePaneActionSummary: String {
        switch menuPrimaryState {
        case .noProfiles:
            return L10n.t("action.save")
        case .dependencyMissing:
            return installationInProgress ? L10n.t("dependency.installingDisplayplacer") : L10n.t("dependency.installDisplayplacer")
        case .manualRecovery:
            return L10n.t("action.fixNow")
        case .healthy:
            return L10n.t("menu.action.none")
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
}
