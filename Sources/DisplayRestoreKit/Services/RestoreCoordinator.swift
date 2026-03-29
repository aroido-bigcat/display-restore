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

    public func decide(for currentDisplays: [DisplaySnapshot], profiles: [DisplayProfile]) -> RestoreDecision {
        guard !currentDisplays.isEmpty else {
            return RestoreDecision(action: .idle, reason: "No displays detected.")
        }

        guard let match = matcher.bestMatch(for: currentDisplays, among: profiles) else {
            return RestoreDecision(
                action: profiles.isEmpty ? .saveNewProfile : .offerManualFix,
                reason: profiles.isEmpty ? "No saved profile exists yet." : "No confident profile match was found."
            )
        }

        let threshold = max(match.profile.settings.confidenceThreshold, matcher.threshold)

        guard match.score >= threshold else {
            return RestoreDecision(
                action: .offerManualFix,
                profileName: match.profile.name,
                score: match.score,
                reason: "Best profile is below the restore confidence threshold."
            )
        }

        guard match.profile.settings.autoRestore else {
            return RestoreDecision(
                action: .offerManualFix,
                profileName: match.profile.name,
                score: match.score,
                reason: "The matched profile has auto restore disabled."
            )
        }

        return RestoreDecision(
            action: .autoRestore(command: match.profile.layout.engine.command),
            profileName: match.profile.name,
            score: match.score,
            reason: "The current display set confidently matches a saved profile."
        )
    }
}

