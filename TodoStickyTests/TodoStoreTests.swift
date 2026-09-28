import CoreGraphics
import Foundation
import XCTest
@testable import TodoSticky

final class TodoStoreTests: XCTestCase {
    func testCreateTrimsWhitespaceAndRejectsEmptyInput() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await MainActor.run { () -> (Bool, Bool, [String]) in
            let store = TodoStore(file: file)
            let rejected = store.addTodo(title: " \n\t ")
            let created = store.addTodo(title: "  Buy milk  ")
            return (rejected, created, store.openTodos.map(\.title))
        }

        XCTAssertFalse(result.0)
        XCTAssertTrue(result.1)
        XCTAssertEqual(result.2, ["Buy milk"])
    }

    func testToggleCompletesAndRestoresTodo() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await MainActor.run { () -> ([TodoItem], [TodoItem], [TodoItem]) in
            let store = TodoStore(file: file)
            store.addTodo(title: "Review notes")
            let id = store.todos[0].id
            store.toggleTodo(id: id)
            let completed = store.completedTodos
            store.toggleTodo(id: id)
            return (completed, store.openTodos, store.completedTodos)
        }

        XCTAssertEqual(result.0.map(\.title), ["Review notes"])
        XCTAssertTrue(result.0[0].isCompleted)
        XCTAssertEqual(result.1.map(\.title), ["Review notes"])
        XCTAssertFalse(result.1[0].isCompleted)
        XCTAssertTrue(result.2.isEmpty)
    }

    func testDeleteRemovesTodo() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let remaining = await MainActor.run { () -> [TodoItem] in
            let store = TodoStore(file: file)
            store.addTodo(title: "Remove me")
            store.deleteTodo(id: store.todos[0].id)
            return store.todos
        }

        XCTAssertTrue(remaining.isEmpty)
    }

    func testUpdateTitleTrimsWhitespaceAndPreservesTodoIdentityAndState() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let createdAt = Date(timeIntervalSince1970: 1_700_000_100.25)

        let result = await MainActor.run { () -> (Bool, UUID, TodoItem?) in
            let store = TodoStore(file: file)
            store.addTodo(title: "Before", createdAt: createdAt)
            let id = store.todos[0].id
            store.toggleTodo(id: id)
            let updated = store.updateTodoTitle(id: id, title: "  After edit \n")
            return (updated, id, store.todos.first)
        }

        XCTAssertTrue(result.0)
        XCTAssertEqual(result.2?.title, "After edit")
        XCTAssertEqual(result.2?.id, result.1)
        XCTAssertTrue(result.2?.isCompleted == true)
        XCTAssertEqual(result.2?.createdAt, createdAt)
    }

    func testEmptyTitleUpdateDoesNotOverwriteOrDeleteTodo() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await MainActor.run { () -> (Bool, [TodoItem]) in
            let store = TodoStore(file: file)
            store.addTodo(title: "Keep this title")
            let id = store.todos[0].id
            let updated = store.updateTodoTitle(id: id, title: " \n\t ")
            return (updated, store.todos)
        }

        XCTAssertFalse(result.0)
        XCTAssertEqual(result.1.count, 1)
        XCTAssertEqual(result.1[0].title, "Keep this title")
    }

    func testUpdatedTitlePersistsWithTodoIdentityAndCompletionState() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let createdAt = Date(timeIntervalSince1970: 1_700_000_200.5)

        let restored = await MainActor.run { () -> (UUID, TodoItem?) in
            let store = TodoStore(file: file)
            store.addTodo(title: "Before", createdAt: createdAt)
            let id = store.todos[0].id
            store.toggleTodo(id: id)
            store.updateTodoTitle(id: id, title: "After")
            return (id, TodoStore(file: file).todos.first)
        }

        XCTAssertEqual(restored.1?.title, "After")
        XCTAssertEqual(restored.1?.id, restored.0)
        XCTAssertTrue(restored.1?.isCompleted == true)
        XCTAssertEqual(restored.1?.createdAt, createdAt)
    }

    func testStoreRoundTripPersistsTodosCompletionAndSelectedColor() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000.123456)

        let restored = await MainActor.run { () -> (StickyAppState, Bool) in
            let firstStore = TodoStore(file: file)
            firstStore.addTodo(title: "Persist me", createdAt: createdAt)
            firstStore.toggleTodo(id: firstStore.todos[0].id)
            firstStore.selectColor(.purple)
            let secondStore = TodoStore(file: file)
            return (StickyAppState(todos: secondStore.todos, selectedColor: secondStore.selectedColor),
                    secondStore.isPersistenceErrorPresented)
        }

        XCTAssertFalse(restored.1)
        XCTAssertEqual(restored.0.selectedColor, .purple)
        XCTAssertEqual(restored.0.todos.count, 1)
        XCTAssertEqual(restored.0.todos[0].title, "Persist me")
        XCTAssertTrue(restored.0.todos[0].isCompleted)
        XCTAssertEqual(restored.0.todos[0].createdAt, createdAt)
    }

    func testTodosAreOrderedNewestFirstWithStableTies() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let earlier = Date(timeIntervalSince1970: 10)
        let sameTime = Date(timeIntervalSince1970: 20)
        let later = Date(timeIntervalSince1970: 20.8)

        let titles = await MainActor.run { () -> [String] in
            let store = TodoStore(file: file)
            store.addTodo(title: "Older", createdAt: earlier)
            store.addTodo(title: "Same-time first", createdAt: sameTime)
            store.addTodo(title: "Same-time second", createdAt: sameTime)
            store.addTodo(title: "Newer", createdAt: later)
            return TodoStore(file: file).openTodos.map(\.title)
        }

        XCTAssertEqual(titles, ["Newer", "Same-time first", "Same-time second", "Older"])
    }

    func testCorruptDataIsPreservedInsteadOfOverwritten() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data("not valid state".utf8)
        try original.write(to: file.fileURL)

        let result = await MainActor.run { () -> Bool in
            let store = TodoStore(file: file)
            XCTAssertTrue(store.isPersistenceErrorPresented)
            store.addTodo(title: "Do not overwrite original")
            return store.isPersistenceErrorPresented
        }

        XCTAssertTrue(result)
        XCTAssertEqual(try Data(contentsOf: file.fileURL), original)
    }

    func testWindowFramePreferencesRoundTrip() throws {
        let suiteName = "TodoStickyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = WindowFramePreferences(defaults: defaults, key: "frame")
        let frame = StickyWindowFrame(x: 140, y: 250, width: 420, height: 300)

        preferences.save(frame)

        XCTAssertEqual(preferences.load(), frame)
    }

    func testOffscreenWindowFrameRecoversOnFallbackScreen() {
        let fallback = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let restored = StickyWindowFrame.restoring(
            saved: StickyWindowFrame(x: 9000, y: -7000, width: 180, height: 120),
            visibleScreenFrames: [fallback],
            fallbackScreenFrame: fallback,
            defaultSize: CGSize(width: 360, height: 460),
            minimumSize: CGSize(width: 320, height: 180)
        )

        XCTAssertGreaterThanOrEqual(restored.width, 320)
        XCTAssertGreaterThanOrEqual(restored.height, 180)
        XCTAssertTrue(restored.rect.intersects(fallback))
        XCTAssertLessThanOrEqual(restored.rect.maxX, fallback.maxX)
        XCTAssertLessThanOrEqual(restored.rect.maxY, fallback.maxY)
    }

    private static func makeTemporaryFile() throws -> (TodoStateFile, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TodoStickyTests.\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return (TodoStateFile(fileURL: directory.appending(path: "state.json")), directory)
    }
}
