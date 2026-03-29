import Testing
@testable import LayoutRecallKit

@Test
func preferredLanguageCodeHonorsExplicitEnvironmentOverride() {
    let languageCode = L10n.preferredLanguageCode(
        environment: ["AppleLanguages": "(en)"],
        preferredLanguages: ["ko-KR"],
        storedAppleLanguages: ["ko-KR"]
    )

    #expect(languageCode == "en")
}

@Test
func preferredLanguageCodeFallsBackToPreferredLanguages() {
    let languageCode = L10n.preferredLanguageCode(
        environment: [:],
        preferredLanguages: ["ko-KR"],
        storedAppleLanguages: ["en-US"]
    )

    #expect(languageCode == "ko")
}

@Test
func preferredLanguageCodeDefaultsToEnglishForUnsupportedValues() {
    let languageCode = L10n.preferredLanguageCode(
        environment: ["AppleLanguages": "(ja-JP)"],
        preferredLanguages: ["fr-FR"],
        storedAppleLanguages: ["de-DE"]
    )

    #expect(languageCode == "en")
}
