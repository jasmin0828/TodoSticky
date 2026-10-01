import Foundation
import XCTest
@testable import TodoSticky

@MainActor
final class AppLanguageControllerTests: XCTestCase {
    func testControllerLoadsStoredLanguageAndResolvesLocale() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(AppLanguage.english.rawValue, forKey: LanguagePreferences.languageKey)
        let preferences = LanguagePreferences(defaults: defaults)
        let controller = AppLanguageController(
            preferences: preferences,
            systemLocale: Locale(identifier: "zh-Hans-CN")
        )

        XCTAssertEqual(controller.language, .english)
        XCTAssertEqual(controller.locale.language.languageCode?.identifier, "en")
    }

    func testChangingLanguagePersistsCanonicalValueAndUpdatesLocale() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = LanguagePreferences(defaults: defaults)
        let controller = AppLanguageController(
            preferences: preferences,
            systemLocale: Locale(identifier: "en-US")
        )

        controller.language = .simplifiedChinese

        XCTAssertEqual(defaults.string(forKey: LanguagePreferences.languageKey), "zh-Hans")
        XCTAssertEqual(controller.locale.language.languageCode?.identifier, "zh")
        XCTAssertEqual(controller.locale.language.script?.identifier, "Hans")
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "TodoStickyTests.AppLanguageController.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.unableToCreateDefaults
        }
        return (defaults, suiteName)
    }
}

private enum TestError: Error {
    case unableToCreateDefaults
}
