import Foundation

public struct RestoreVerifier: RestoreVerifying {
    public var retryDelays: [UInt64]

    public init(retryDelays: [UInt64] = [750_000_000, 1_500_000_000, 3_000_000_000]) {
        self.retryDelays = retryDelays
    }

    public func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult {
        guard !expectedOrigins.isEmpty else {
            return RestoreVerificationResult(
                outcome: .unverified,
                attempts: 0,
                details: L10n.t("verify.noExpectedOrigins")
            )
        }

        for (index, delay) in retryDelays.enumerated() {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                let currentDisplays = try await reader.currentDisplays()
                if mismatches(for: currentDisplays, expectedOrigins: expectedOrigins).isEmpty {
                    return RestoreVerificationResult(
                        outcome: .success,
                        attempts: index + 1,
                        details: L10n.t("verify.match")
                    )
                }

                if index == retryDelays.count - 1 {
                    let mismatchDetails = mismatches(for: currentDisplays, expectedOrigins: expectedOrigins)
                        .joined(separator: "; ")

                    return RestoreVerificationResult(
                        outcome: .failed,
                        attempts: retryDelays.count,
                        details: mismatchDetails.isEmpty
                            ? L10n.t("verify.mismatchGeneric")
                            : mismatchDetails
                    )
                }
            } catch {
                if index == retryDelays.count - 1 {
                    return RestoreVerificationResult(
                        outcome: .unverified,
                        attempts: retryDelays.count,
                        details: L10n.t("verify.readFailed", error.localizedDescription)
                    )
                }
            }
        }

        return RestoreVerificationResult(
            outcome: .unverified,
            attempts: retryDelays.count,
            details: L10n.t("verify.noFinalComparison")
        )
    }

    private func mismatches(for currentDisplays: [DisplaySnapshot], expectedOrigins: [DisplayOrigin]) -> [String] {
        expectedOrigins.compactMap { expected in
            guard let current = currentDisplays.first(where: { $0.matches(storedKey: expected.key) }) else {
                return L10n.t("verify.missingDisplay", expected.key)
            }

            guard current.bounds.x == expected.x, current.bounds.y == expected.y else {
                return L10n.t("verify.wrongOrigin", expected.key, expected.x, expected.y, current.bounds.x, current.bounds.y)
            }

            return nil
        }
    }
}
