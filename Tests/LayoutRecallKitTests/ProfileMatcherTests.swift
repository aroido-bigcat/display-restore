import Foundation
import Testing
@testable import LayoutRecallKit

@Test
func exactIdentifiersMatchEvenWhenDisplayOrderChanges() {
    let matcher = ProfileMatcher()
    let reversedCurrentDisplays = [DisplaySnapshot.sampleRight, DisplaySnapshot.sampleLeft]

    let match = matcher.bestMatch(for: reversedCurrentDisplays, among: [.officeDock])

    #expect(match?.profile.name == "Office Dock")
    #expect((match?.score ?? 0) >= 70)
}

@Test
func countMismatchRejectsProfile() {
    let matcher = ProfileMatcher()
    let oneDisplay = [DisplaySnapshot.sampleLeft]

    let match = matcher.bestMatch(for: oneDisplay, among: [.officeDock])

    #expect(match == nil)
}

@Test
func weakSignalsStayInManualRecoveryFlow() {
    var unknownLeft = DisplaySnapshot.sampleLeft
    unknownLeft.id = "unknown-left"
    unknownLeft.serialNumber = nil
    unknownLeft.alphaSerialNumber = nil
    unknownLeft.persistentID = nil
    unknownLeft.contextualID = nil

    var unknownRight = DisplaySnapshot.sampleRight
    unknownRight.id = "unknown-right"
    unknownRight.serialNumber = nil
    unknownRight.alphaSerialNumber = nil
    unknownRight.persistentID = nil
    unknownRight.contextualID = nil

    let coordinator = RestoreCoordinator()
    let decision = coordinator.decide(for: [unknownLeft, unknownRight], profiles: [.officeDock])

    #expect(decision.action == .offerManualFix)
    #expect(decision.profileName == "Office Dock")
}

@Test
func liveHardwareDisplaySnapshotMatchesItsOwnDraftProfile() async throws {
    guard ProcessInfo.processInfo.environment["DISPLAY_RESTORE_RUN_LIVE_HARDWARE_TESTS"] == "1" else {
        return
    }

    let displays = try await DisplaySnapshotReader().currentDisplays()
    #expect(displays.count >= 2)

    let uniqueKeys = Set(displays.map { displays.uniqueMatchKey(for: $0) })
    #expect(uniqueKeys.count == displays.count)

    for display in displays {
        #expect(display.resolution.width > 0)
        #expect(display.resolution.height > 0)
    }

    let plan = try DisplayplacerCommandBuilder().restorePlan(for: displays)
    let profile = DisplayProfile.draft(
        name: "Live Hardware",
        displays: displays,
        layoutPlan: plan
    )

    let coordinator = RestoreCoordinator()
    let decision = coordinator.decide(
        for: displays,
        profiles: [profile],
        dependencyAvailable: true
    )

    #expect(decision.profileName == "Live Hardware")
    #expect(decision.action == .autoRestore(command: profile.layout.engine.command))
}
