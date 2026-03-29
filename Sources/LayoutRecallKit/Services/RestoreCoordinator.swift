import Foundation

public enum RestoreAction: Equatable, Sendable {
    case autoRestore(command: String)
    case offerManualFix
    case saveNewProfile
    case idle
}

public struct RestoreDecision: Equatable, Sendable {
    public var action: RestoreAction
    public var profileName: String?
    public var score: Int?
    public var reason: String

    public init(action: RestoreAction, profileName: String? = nil, score: Int? = nil, reason: String) {
        self.action = action
        self.profileName = profileName
        self.score = score
        self.reason = reason
    }
}

public struct RestoreCoordinator: Sendable {
    public var matcher: ProfileMatcher

    public init(matcher: ProfileMatcher = ProfileMatcher()) {
        self.matcher = matcher
    }

    public func decide(
        for currentDisplays: [DisplaySnapshot],
        profiles: [DisplayProfile],
        dependencyAvailable: Bool = true
    ) -> RestoreDecision {
        guard !currentDisplays.isEmpty else {
            return RestoreDecision(action: .idle, reason: L10n.t("restoreDecision.noDisplaysDetected"))
        }

        guard let match = matcher.bestMatch(for: currentDisplays, among: profiles) else {
            return RestoreDecision(
                action: profiles.isEmpty ? .saveNewProfile : .offerManualFix,
                reason: profiles.isEmpty ? L10n.t("restoreDecision.noSavedProfile") : L10n.t("restoreDecision.noConfidentProfileMatch")
            )
        }

        let threshold = max(match.profile.settings.confidenceThreshold, matcher.threshold)

        guard match.score >= threshold else {
            return RestoreDecision(
                action: .offerManualFix,
                profileName: match.profile.name,
                score: match.score,
                reason: L10n.t("restoreDecision.belowThreshold")
            )
        }

        guard match.profile.settings.autoRestore else {
            return RestoreDecision(
                action: .offerManualFix,
                profileName: match.profile.name,
                score: match.score,
                reason: L10n.t("restoreDecision.autoRestoreDisabled")
            )
        }

        guard dependencyAvailable else {
            return RestoreDecision(
                action: .offerManualFix,
                profileName: match.profile.name,
                score: match.score,
                reason: L10n.t("restoreDecision.dependencyBlocked")
            )
        }

        return RestoreDecision(
            action: .autoRestore(command: match.profile.layout.engine.command),
            profileName: match.profile.name,
            score: match.score,
            reason: L10n.t("restoreDecision.confidentMatch")
        )
    }
}
