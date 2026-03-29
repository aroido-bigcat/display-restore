import Testing
@testable import LayoutRecallKit

@Test
func dependencyMissingBlocksAutomaticRestore() {
    let coordinator = RestoreCoordinator()

    let decision = coordinator.decide(
        for: [DisplaySnapshot.sampleLeft, DisplaySnapshot.sampleRight],
        profiles: [.officeDock],
        dependencyAvailable: false
    )

    #expect(decision.action == .offerManualFix)
    #expect(decision.profileName == "Office Dock")
}
