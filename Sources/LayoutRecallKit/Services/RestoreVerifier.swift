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
                details: "No expected display origins were provided for verification."
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
                        details: "Display layout matches the expected saved origins."
                    )
                }

                if index == retryDelays.count - 1 {
                    let mismatchDetails = mismatches(for: currentDisplays, expectedOrigins: expectedOrigins)
                        .joined(separator: "; ")

                    return RestoreVerificationResult(
                        outcome: .failed,
                        attempts: retryDelays.count,
                        details: mismatchDetails.isEmpty
                            ? "Display layout does not match the expected saved origins."
                            : mismatchDetails
                    )
                }
            } catch {
                if index == retryDelays.count - 1 {
                    return RestoreVerificationResult(
                        outcome: .unverified,
                        attempts: retryDelays.count,
                        details: "Verification failed because the current display set could not be read: \(error.localizedDescription)"
                    )
                }
            }
        }

        return RestoreVerificationResult(
            outcome: .unverified,
            attempts: retryDelays.count,
            details: "Verification ended without a final display comparison."
        )
    }

    private func mismatches(for currentDisplays: [DisplaySnapshot], expectedOrigins: [DisplayOrigin]) -> [String] {
        expectedOrigins.compactMap { expected in
            guard let current = currentDisplays.first(where: { $0.matches(storedKey: expected.key) }) else {
                return "Missing display for key \(expected.key)."
            }

            guard current.bounds.x == expected.x, current.bounds.y == expected.y else {
                return "Display \(expected.key) expected origin (\(expected.x),\(expected.y)) but was (\(current.bounds.x),\(current.bounds.y))."
            }

            return nil
        }
    }
}
