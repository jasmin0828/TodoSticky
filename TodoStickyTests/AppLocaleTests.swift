import XCTest
@testable import TodoSticky

final class AppLocaleTests: XCTestCase {
    func testExplicitEnglishResolvesToEnglish() {
        let locale = AppLocaleResolver.locale(for: .english)

        XCTAssertEqual(locale.language.languageCode?.identifier, "en")
    }

    func testExplicitSimplifiedChineseResolvesToSimplifiedChinese() {
        let locale = AppLocaleResolver.locale(for: .simplifiedChinese)

        XCTAssertEqual(locale.language.languageCode?.identifier, "zh")
        XCTAssertEqual(locale.language.script?.identifier, "Hans")
    }

    func testSystemSimplifiedChineseResolvesToSimplifiedChinese() {
        let locale = AppLocaleResolver.locale(
            for: .system,
            systemLocale: Locale(identifier: "zh-Hans-CN")
        )

        XCTAssertEqual(locale.language.languageCode?.identifier, "zh")
        XCTAssertEqual(locale.language.script?.identifier, "Hans")
    }

    func testSystemTraditionalChineseFallsBackToEnglish() {
        let locale = AppLocaleResolver.locale(
            for: .system,
            systemLocale: Locale(identifier: "zh-Hant-TW")
        )

        XCTAssertEqual(locale.language.languageCode?.identifier, "en")
    }

    func testSystemEnglishResolvesToEnglish() {
        let locale = AppLocaleResolver.locale(
            for: .system,
            systemLocale: Locale(identifier: "en-US")
        )

        XCTAssertEqual(locale.language.languageCode?.identifier, "en")
    }

    func testUnsupportedSystemLanguageFallsBackToEnglish() {
        let locale = AppLocaleResolver.locale(
            for: .system,
            systemLocale: Locale(identifier: "fr-FR")
        )

        XCTAssertEqual(locale.language.languageCode?.identifier, "en")
    }

    func testSharedPreferencesResolveExplicitChinese() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: LanguagePreferences.languageKey)

        let locale = AppLocaleResolver.locale(
            for: LanguagePreferences(defaults: defaults),
            systemLocale: Locale(identifier: "en-US")
        )

        XCTAssertEqual(locale.identifier, "zh-Hans")
    }

    func testSharedPreferencesMissingValueFollowsSystemWithoutWriting() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let locale = AppLocaleResolver.locale(
            for: LanguagePreferences(defaults: defaults),
            systemLocale: Locale(identifier: "zh-Hans-CN")
        )

        XCTAssertEqual(locale.identifier, "zh-Hans")
        XCTAssertNil(defaults.object(forKey: LanguagePreferences.languageKey))
    }

    func testCatalogContainsEnglishAndSimplifiedChineseTranslations() throws {
        let appBundle = try XCTUnwrap(Bundle(identifier: "com.jasminstudio.TodoSticky"))
        let englishPath = try XCTUnwrap(appBundle.path(forResource: "en", ofType: "lproj"))
        let chinesePath = try XCTUnwrap(appBundle.path(forResource: "zh-Hans", ofType: "lproj"))
        let englishBundle = try XCTUnwrap(Bundle(path: englishPath))
        let chineseBundle = try XCTUnwrap(Bundle(path: chinesePath))

        XCTAssertEqual(
            englishBundle.localizedString(forKey: "todo.header.title", value: nil, table: "Localizable"),
            "Todos"
        )
        XCTAssertEqual(
            chineseBundle.localizedString(forKey: "todo.header.title", value: nil, table: "Localizable"),
            "待办"
        )
        XCTAssertEqual(
            chineseBundle.localizedString(forKey: "widget.storageUnavailable", value: nil, table: "Localizable"),
            "共享数据暂时不可用"
        )
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "TodoStickyTests.AppLocale.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.unableToCreateDefaults
        }
        return (defaults, suiteName)
    }
}

private enum TestError: Error {
    case unableToCreateDefaults
}
