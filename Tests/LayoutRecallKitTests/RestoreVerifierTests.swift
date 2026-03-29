import Foundation
import Testing
@testable import LayoutRecallKit

private struct StubSnapshotReader: DisplaySnapshotReading {
    let snapshotsByRead: [[DisplaySnapshot]]
    let failure: Error?
    private let state = LockedState()

    func currentDisplays() async throws -> [DisplaySnapshot] {
        if let failure {
            throw failure
        }

        return state.next(from: snapshotsByRead)
    }

    private final class LockedState: @unchecked Sendable {
        private let lock = NSLock()
        private var index = 0

        func next(from snapshotsByRead: [[DisplaySnapshot]]) -> [DisplaySnapshot] {
            lock.lock()
            defer { lock.unlock() }

            let clampedIndex = min(index, snapshotsByRead.count - 1)
            index += 1
            return snapshotsByRead[clampedIndex]
        }
    }
}

@Test
func verifierSucceedsWhenTheExpectedOriginsAppear() async {
    let verifier = RestoreVerifier(retryDelays: [0])
    let reader = StubSnapshotReader(
        snapshotsByRead: [[DisplaySnapshot.sampleLeft, DisplaySnapshot.sampleRight]],
        failure: nil
    )

    let result = await verifier.verify(
        expectedOrigins: DisplayProfile.officeDock.layout.expectedOrigins,
        using: reader
    )

    #expect(result.outcome == .success)
    #expect(result.attempts == 1)
}

@Test
func verifierFailsAfterAllRetriesWhenOriginsNeverMatch() async {
    let verifier = RestoreVerifier(retryDelays: [0, 0])

    var misplacedLeft = DisplaySnapshot.sampleLeft
    misplacedLeft.bounds.x = 1024
    var misplacedRight = DisplaySnapshot.sampleRight
    misplacedRight.bounds.x = 2048

    let reader = StubSnapshotReader(
        snapshotsByRead: [[misplacedLeft, misplacedRight]],
        failure: nil
    )

    let result = await verifier.verify(
        expectedOrigins: DisplayProfile.officeDock.layout.expectedOrigins,
        using: reader
    )

    #expect(result.outcome == .failed)
    #expect(result.attempts == 2)
}

@Test
func verifierReportsUnverifiedWhenSnapshotReadsFail() async {
    let verifier = RestoreVerifier(retryDelays: [0])
    let reader = StubSnapshotReader(
        snapshotsByRead: [],
        failure: DisplaySnapshotReaderError.onlineDisplayListFailed(.failure)
    )

    let result = await verifier.verify(
        expectedOrigins: DisplayProfile.officeDock.layout.expectedOrigins,
        using: reader
    )

    #expect(result.outcome == .unverified)
    #expect(result.attempts == 1)
}
