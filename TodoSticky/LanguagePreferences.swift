import Foundation

enum LanguagePreferencesError: Error, Equatable, Sendable {
    case sharedDefaultsUnavailable
}

struct LanguagePreferences {
    static let suiteName = TodoStateFile.applicationGroupIdentifier
    static let languageKey = "preferences.language"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    static func appGroup() throws -> Self {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw LanguagePreferencesError.sharedDefaultsUnavailable
        }
        return Self(defaults: defaults)
    }

    var language: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Self.languageKey),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .system
            }
            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.languageKey)
        }
    }
}
