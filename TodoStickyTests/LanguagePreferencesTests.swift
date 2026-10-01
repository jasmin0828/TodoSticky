import Foundation
import XCTest
@testable import TodoSticky

final class LanguagePreferencesTests: XCTestCase {
    func testCanonicalLanguageRawValues() {
        XCTAssertEqual(AppLanguage.system.rawValue, "system")
        XCTAssertEqual(AppLanguage.simplifiedChinese.rawValue, "zh-Hans")
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
    }

    func testLanguageCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for language in AppLanguage.allCases {
            let data = try encoder.encode(language)
            XCTAssertEqual(try decoder.decode(AppLanguage.self, from: data), language)
        }
    }

    func testMissingLanguageDefaultsToSystem() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = LanguagePreferences(defaults: defaults)

        XCTAssertEqual(preferences.language, .system)
    }

    func testUnknownStoredLanguageDefaultsToSystem() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("fr", forKey: LanguagePreferences.languageKey)
        let preferences = LanguagePreferences(defaults: defaults)

        XCTAssertEqual(preferences.language, .system)
    }

    func testLanguagePersistsAsCanonicalRawValue() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var preferences = LanguagePreferences(defaults: defaults)
        preferences.language = .simplifiedChinese

        XCTAssertEqual(defaults.string(forKey: LanguagePreferences.languageKey), "zh-Hans")
        XCTAssertEqual(preferences.language, .simplifiedChinese)

        preferences = LanguagePreferences(defaults: defaults)
        XCTAssertEqual(preferences.language, .simplifiedChinese)
    }

    func testStorageUsesExistingTodoAppGroupIdentifier() {
        XCTAssertEqual(
            LanguagePreferences.suiteName,
            TodoStateFile.applicationGroupIdentifier
        )
    }

    private static func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "TodoStickyTests.LanguagePreferences.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.unableToCreateDefaults
        }
        return (defaults, suiteName)
    }
}

private enum TestError: Error {
    case unableToCreateDefaults
}
