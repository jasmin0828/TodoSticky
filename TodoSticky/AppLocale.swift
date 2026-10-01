import Foundation

enum AppLocaleResolver {
    static let english = Locale(identifier: "en")
    static let simplifiedChinese = Locale(identifier: "zh-Hans")

    static func localizedString(
        forKey key: String,
        locale: Locale,
        value: String? = nil,
        table: String = "Localizable"
    ) -> String {
        let bundles = [
            Bundle(for: AppLocaleBundleMarker.self),
            Bundle.main
        ]

        for bundle in bundles {
            guard let resourceURL = bundle.url(
                forResource: locale.identifier,
                withExtension: "lproj"
            ), let localizedBundle = Bundle(url: resourceURL) else {
                continue
            }

            return localizedBundle.localizedString(
                forKey: key,
                value: value,
                table: table
            )
        }

        return value ?? key
    }

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

private final class AppLocaleBundleMarker {}
