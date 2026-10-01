import Foundation
import Observation

@MainActor
@Observable
final class AppLanguageController {
    @ObservationIgnored private var preferences: LanguagePreferences?
    @ObservationIgnored private let systemLocale: Locale

    var language: AppLanguage {
        didSet {
            preferences?.language = language
        }
    }

    var locale: Locale {
        AppLocaleResolver.locale(for: language, systemLocale: systemLocale)
    }

    init(
        preferences: LanguagePreferences? = try? LanguagePreferences.appGroup(),
        systemLocale: Locale = .current
    ) {
        self.preferences = preferences
        self.systemLocale = systemLocale
        language = preferences?.language ?? .system
    }
}
