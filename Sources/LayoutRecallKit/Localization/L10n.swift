import Foundation

public enum L10n {
    static func preferredLanguageCode(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        preferredLanguages: [String] = Locale.preferredLanguages,
        storedAppleLanguages: [String]? = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
    ) -> String {
        let candidates =
            parsedAppleLanguages(environment["AppleLanguages"]) +
            preferredLanguages +
            (storedAppleLanguages ?? [])

        return candidates
            .lazy
            .map { $0.lowercased() }
            .compactMap { languageTag -> String? in
                if languageTag.hasPrefix("ko") {
                    return "ko"
                }

                if languageTag.hasPrefix("en") {
                    return "en"
                }

                return nil
            }
            .first
            ?? "en"
    }

    private static func parsedAppleLanguages(_ rawValue: String?) -> [String] {
        guard let rawValue else {
            return []
        }

        return rawValue
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .split(whereSeparator: { separator in
                separator == "," || separator.isWhitespace || separator.isNewline
            })
            .map(String.init)
    }

    private static func localizedBundle(for languageCode: String) -> Bundle {
        guard
            let bundlePath = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            return Bundle.module
        }

        return bundle
    }

    private static var localizedBundle: Bundle {
        localizedBundle(for: preferredLanguageCode())
    }

    public static func t(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    public static func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: Locale.current, arguments: arguments)
    }

    public static func profileCount(_ count: Int) -> String {
        t(count == 1 ? "profile.count.one" : "profile.count.other", count)
    }

    public static func settingsProfileCount(_ count: Int) -> String {
        t(count == 1 ? "settings.profile.count.one" : "settings.profile.count.other", count)
    }

    public static func layoutDisplayCount(_ count: Int) -> String {
        t(count == 1 ? "layout.display.count.one" : "layout.display.count.other", count)
    }

    public static func connectedDisplayCount(_ count: Int) -> String {
        t(count == 1 ? "connected.display.count.one" : "connected.display.count.other", count)
    }

    public static func workspaceName(_ index: Int) -> String {
        t("workspace.name", index)
    }

    public static func score(_ score: Int) -> String {
        t("score.value", score)
    }

    public static func confidenceThreshold(_ value: Int) -> String {
        t("confidence.threshold", value)
    }

    public static func eventTypeName(_ rawValue: String) -> String {
        switch rawValue {
        case DisplayEventType.reconfigured.rawValue:
            return t("event.type.reconfigured")
        case DisplayEventType.wake.rawValue:
            return t("event.type.wake")
        case DisplayEventType.manual.rawValue:
            return t("event.type.manual")
        case DisplayEventType.restoreVerification.rawValue:
            return t("event.type.restoreVerification")
        default:
            return rawValue
        }
    }
}
