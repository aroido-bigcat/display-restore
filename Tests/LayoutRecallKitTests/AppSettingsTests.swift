import Foundation
import Testing
@testable import LayoutRecallKit

@Test
func appSettingsDecodesLegacyPayloadWithoutUpdateFields() throws {
    let data = Data(
        """
        {
          "launchAtLogin" : true,
          "shortcuts" : {
            "fixNow" : {
              "keyCode" : 15,
              "keyDisplay" : "R",
              "modifiersRawValue" : 1572864
            }
          }
        }
        """.utf8
    )

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(settings.launchAtLogin == true)
    #expect(settings.shortcuts.fixNow?.keyDisplay == "R")
    #expect(settings.automaticallyCheckForUpdates == true)
    #expect(settings.skippedReleaseVersion == nil)
}
