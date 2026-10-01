import Foundation
import XCTest
@testable import TodoSticky

@MainActor
final class SettingsColorTests: XCTestCase {
    func testSettingsColorChoicesAreCanonicalStickyColors() {
        XCTAssertEqual(
            StickyColor.allCases,
            [.yellow, .blue, .green, .pink, .purple, .gray]
        )
    }

    func testColorNamesResolveFromSelectedLocale() {
        XCTAssertEqual(StickyColor.yellow.title(locale: AppLocaleResolver.english), "Yellow")
        XCTAssertEqual(StickyColor.yellow.title(locale: AppLocaleResolver.simplifiedChinese), "黄色")
        XCTAssertEqual(StickyColor.purple.title(locale: AppLocaleResolver.english), "Purple")
        XCTAssertEqual(StickyColor.purple.title(locale: AppLocaleResolver.simplifiedChinese), "紫色")
    }

    func testSelectingColorMutatesOnlySelectedColor() throws {
        let (file, directory) = try makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let todos = [
            TodoItem(
                id: UUID(uuidString: "0A1B2C3D-4E5F-4678-89AB-CDEF01234567")!,
                title: "First",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            TodoItem(
                id: UUID(uuidString: "1A2B3C4D-5E6F-4789-8ABC-DEF012345678")!,
                title: "Second",
                isCompleted: true,
                createdAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        ]
        try file.save(StickyAppState(todos: todos, selectedColor: .yellow))

        let store = TodoStore(file: file)
        store.selectColor(.purple)
        let persisted = try file.load()

        XCTAssertEqual(persisted.selectedColor, .purple)
        XCTAssertEqual(persisted.todos, todos)
    }

    func testLanguagePreferenceDoesNotChangeTodoStateBytes() throws {
        let (file, directory) = try makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try file.save(StickyAppState(todos: [TodoItem(title: "Stable")], selectedColor: .green))
        let before = try Data(contentsOf: file.fileURL)

        let preferences = LanguagePreferences(defaults: try makeDefaults())
        let controller = AppLanguageController(preferences: preferences)
        controller.language = .english
        controller.language = .simplifiedChinese
        controller.language = .english

        XCTAssertEqual(try Data(contentsOf: file.fileURL), before)
    }

    private func makeTemporaryFile() throws -> (TodoStateFile, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TodoSticky.SettingsColorTests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (TodoStateFile(fileURL: directory.appending(path: "todo-state.json")), directory)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "TodoStickyTests.SettingsColor.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.unableToCreateDefaults
        }
        return defaults
    }
}

private enum TestError: Error {
    case unableToCreateDefaults
}
