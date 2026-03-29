import Testing
@testable import LayoutRecallKit

@Test
func restorePlanBuildsAStableDisplayplacerCommand() throws {
    let builder = DisplayplacerCommandBuilder()

    let plan = try builder.restorePlan(for: [DisplaySnapshot.sampleRight, DisplaySnapshot.sampleLeft])

    #expect(plan.command.contains("displayplacer"))
    #expect(plan.command.contains("id:persistent-left enabled:true"))
    #expect(plan.command.contains("origin:(0,0)"))
    #expect(plan.command.contains("scaling:off"))
    #expect(plan.command.contains("id:persistent-right enabled:true"))
    #expect(plan.command.contains("origin:(2560,0)"))
    #expect(plan.expectedOrigins.count == 2)
}

@Test
func swapLeftRightPlanSwapsTheTwoDisplayOrigins() throws {
    let builder = DisplayplacerCommandBuilder()

    let plan = try builder.swapLeftRightPlan(for: [DisplaySnapshot.sampleLeft, DisplaySnapshot.sampleRight])

    #expect(plan.command.contains("id:persistent-left enabled:true origin:(2560,0)"))
    #expect(plan.command.contains("id:persistent-right enabled:true origin:(0,0)"))
    #expect(plan.expectedOrigins[0].x == 2560)
    #expect(plan.expectedOrigins[1].x == 0)
}

@Test
func swapLeftRightRejectsNonDualDisplayLayouts() {
    let builder = DisplayplacerCommandBuilder()

    do {
        _ = try builder.swapLeftRightPlan(for: [DisplaySnapshot.sampleLeft])
        Issue.record("Expected the builder to reject non-dual display swap attempts.")
    } catch {
        #expect(error is LayoutRecallRuntimeError)
    }
}

@Test
func restorePlanUsesLogicalResolutionForScaledDisplays() throws {
    let builder = DisplayplacerCommandBuilder()
    let scaledDisplay = DisplaySnapshot(
        id: "3",
        persistentID: "4e747025-110e-4dcd-bd2f-cd0f28d043d5",
        resolution: DisplayResolution(width: 3840, height: 2160),
        refreshRate: 60,
        scale: 2.0,
        bounds: DisplayRect(x: 0, y: 0, width: 1920, height: 1080)
    )

    let plan = try builder.restorePlan(for: [scaledDisplay])

    #expect(plan.command.contains("id:4E747025-110E-4DCD-BD2F-CD0F28D043D5"))
    #expect(plan.command.contains("res:1920x1080"))
    #expect(plan.command.contains("enabled:true"))
}
