import Testing
@testable import DisplayRestoreKit

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
