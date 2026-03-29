import Foundation

public struct ProfileMatch: Equatable, Sendable {
    public var profile: DisplayProfile
    public var score: Int
    public var reasons: [String]

    public init(profile: DisplayProfile, score: Int, reasons: [String]) {
        self.profile = profile
        self.score = score
        self.reasons = reasons
    }
}

public struct ProfileMatcher: Sendable {
    public var threshold: Int

    public init(threshold: Int = 70) {
        self.threshold = threshold
    }

    public func bestMatch(for currentDisplays: [DisplaySnapshot], among profiles: [DisplayProfile]) -> ProfileMatch? {
        profiles
            .compactMap { score(profile: $0, against: currentDisplays) }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.profile.createdAt > rhs.profile.createdAt
                }

                return lhs.score > rhs.score
            }
            .first
    }

    public func score(profile: DisplayProfile, against currentDisplays: [DisplaySnapshot]) -> ProfileMatch? {
        guard profile.displaySet.count == currentDisplays.count else {
            return nil
        }

        var remainingStored = profile.displaySet.displays
        var total = 5
        var reasons: [String] = []

        for current in currentDisplays {
            guard let winner = bestStoredDisplay(for: current, candidates: remainingStored) else {
                return nil
            }

            total += winner.score
            reasons.append(winner.reason)
            remainingStored.remove(at: winner.index)
        }

        if !remainingStored.isEmpty {
            total -= 15 * remainingStored.count
        }

        if profile.displaySet.fingerprint == currentDisplays.fingerprint {
            total += 12
            reasons.append("fingerprint-match")
        }

        return ProfileMatch(profile: profile, score: max(0, total), reasons: reasons)
    }

    private func bestStoredDisplay(
        for current: DisplaySnapshot,
        candidates: [DisplaySnapshot]
    ) -> (index: Int, score: Int, reason: String)? {
        candidates.enumerated().map { index, stored in
            let scored = score(current: current, stored: stored)
            return (index: index, score: scored.score, reason: scored.reason)
        }
        .max { lhs, rhs in
            lhs.score < rhs.score
        }
    }

    private func score(current: DisplaySnapshot, stored: DisplaySnapshot) -> (score: Int, reason: String) {
        var total = 0
        var reasons: [String] = []

        if current.alphaSerialNumber == stored.alphaSerialNumber, current.alphaSerialNumber != nil {
            total += 40
            reasons.append("alpha-serial")
        }

        if current.serialNumber == stored.serialNumber, current.serialNumber != nil {
            total += 30
            reasons.append("serial")
        }

        if current.persistentID == stored.persistentID, current.persistentID != nil {
            total += 18
            reasons.append("persistent-id")
        }

        if current.contextualID == stored.contextualID, current.contextualID != nil {
            total += 10
            reasons.append("contextual-id")
        }

        if current.vendorID == stored.vendorID, current.vendorID != nil {
            total += 3
            reasons.append("vendor")
        }

        if current.productID == stored.productID, current.productID != nil {
            total += 3
            reasons.append("product")
        }

        if current.resolution == stored.resolution {
            total += 8
            reasons.append("resolution")
        } else {
            total -= 12
        }

        if current.refreshRate == stored.refreshRate, current.refreshRate != nil {
            total += 4
            reasons.append("refresh")
        }

        if current.scale == stored.scale, current.scale != nil {
            total += 4
            reasons.append("scale")
        }

        let reason = reasons.isEmpty ? "weak-signal" : reasons.joined(separator: ",")
        return (score: total, reason: reason)
    }
}

