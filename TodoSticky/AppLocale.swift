import Foundation

enum AppLocaleResolver {
    static let english = Locale(identifier: "en")
    static let simplifiedChinese = Locale(identifier: "zh-Hans")

    static func locale(for language: AppLanguage, systemLocale: Locale = .current) -> Locale {
        switch language {
        case .system:
            effectiveSystemLocale(systemLocale)
        case .simplifiedChinese:
            simplifiedChinese
        case .english:
            english
        }
    }

    private static func effectiveSystemLocale(_ locale: Locale) -> Locale {
        guard locale.language.languageCode?.identifier == "zh" else {
            return english
        }

        if locale.language.script?.identifier == "Hant"
            || locale.region?.identifier == "TW"
            || locale.region?.identifier == "HK"
            || locale.region?.identifier == "MO" {
            return english
        }

        return simplifiedChinese
    }
}
