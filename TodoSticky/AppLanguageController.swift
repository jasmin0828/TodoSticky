import Foundation
import Observation

@MainActor
@Observable
final class AppLanguageController {
    @ObservationIgnored private var preferences: LanguagePreferences?
    @ObservationIgnored private let systemLocale: Locale
    @ObservationIgnored private let reloadWidgetTimelines: @MainActor () -> Void

    private var storedLanguage: AppLanguage

    var language: AppLanguage {
        get { storedLanguage }
        set {
            guard newValue != storedLanguage, preferences != nil else { return }
            preferences?.language = newValue
            storedLanguage = newValue
            reloadWidgetTimelines()
        }
    }

    var locale: Locale {
        AppLocaleResolver.locale(for: language, systemLocale: systemLocale)
    }

    init(
        preferences: LanguagePreferences? = try? LanguagePreferences.appGroup(),
        systemLocale: Locale = .current,
        reloadWidgetTimelines: @escaping @MainActor () -> Void = {}
    ) {
        self.preferences = preferences
        self.systemLocale = systemLocale
        self.reloadWidgetTimelines = reloadWidgetTimelines
        storedLanguage = preferences?.language ?? .system
    }
}
