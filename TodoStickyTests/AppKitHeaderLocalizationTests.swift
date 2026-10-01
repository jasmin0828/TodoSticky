import XCTest
@testable import TodoSticky

@MainActor
final class AppKitHeaderLocalizationTests: XCTestCase {
    func testRepresentableUsesDistinctLocaleIdentifiersForSupportedLanguages() {
        let chinese = StickyHeader(localeIdentifier: AppLocaleResolver.simplifiedChinese.identifier)
        let english = StickyHeader(localeIdentifier: AppLocaleResolver.english.identifier)

        XCTAssertEqual(chinese.localeIdentifier, "zh-Hans")
        XCTAssertEqual(english.localeIdentifier, "en")
        XCTAssertNotEqual(chinese.localeIdentifier, english.localeIdentifier)
    }

    func testHeaderTitleUsesSelectedLocaleResource() {
        XCTAssertEqual(StickyHeaderView.localizedTitle(localeIdentifier: "zh-Hans"), "待办")
        XCTAssertEqual(StickyHeaderView.localizedTitle(localeIdentifier: "en"), "Todos")
    }
}
