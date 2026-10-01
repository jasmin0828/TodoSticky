import CoreGraphics
import Foundation
import XCTest
@testable import TodoSticky

final class TodoStoreTests: XCTestCase {
    func testCreateTrimsWhitespaceAndRejectsEmptyInput() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await MainActor.run { () -> (Bool, Bool, [TodoItem]) in
            let store = TodoStore(file: file)
            let rejected = store.addTodo(title: " \n\t ")
            let created = store.addTodo(title: "  Buy milk  ")
            return (rejected, created, store.todos)
        }

        XCTAssertFalse(result.0)
        XCTAssertTrue(result.1)
        XCTAssertEqual(result.2.map(\.title), ["Buy milk"])
        XCTAssertEqual(result.2[0].completionRevision, 0)
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
        XCTAssertEqual(result.0[0].completionRevision, 1)
        XCTAssertEqual(result.1[0].completionRevision, 2)
        XCTAssertTrue(result.2.isEmpty)
    }

    func testLegacyTodoDecodesWithZeroRevisionAndPersistsRevisionAfterMutation() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let legacyJSON = """
        {"todos":[{"id":"\(id.uuidString)","title":"Legacy","isCompleted":false,"createdAt":0}],"selectedColor":"yellow"}
        """
        try Data(legacyJSON.utf8).write(to: file.fileURL)

        XCTAssertEqual(try file.load().todos.first?.completionRevision, 0)

        let result = try file.setCompletion(id: id, targetState: true, expectedRevision: 0)

        XCTAssertEqual(result.disposition, .changed)
        XCTAssertEqual(result.canonicalState.todos.first?.completionRevision, 1)
        XCTAssertEqual(try file.load().todos.first?.completionRevision, 1)
    }

    func testCompletionMutationChangesOnceAndMatchingAlreadyTargetIsNoOp() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Complete me")
        try file.save(StickyAppState(todos: [todo]))

        let changed = try file.setCompletion(id: todo.id, targetState: true, expectedRevision: 0)
        XCTAssertEqual(changed.disposition, .changed)
        XCTAssertTrue(changed.canonicalState.todos[0].isCompleted)
        XCTAssertEqual(changed.canonicalState.todos[0].completionRevision, 1)

        let bytesAfterChange = try Data(contentsOf: file.fileURL)
        let alreadyTarget = try file.setCompletion(id: todo.id, targetState: true, expectedRevision: 1)

        XCTAssertEqual(alreadyTarget.disposition, .alreadyAtTarget)
        XCTAssertEqual(alreadyTarget.canonicalState.todos[0].completionRevision, 1)
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytesAfterChange)
    }

    func testRepeatedOldRequestIsIdempotentWithoutSecondWrite() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Duplicate request")
        try file.save(StickyAppState(todos: [todo]))

        XCTAssertEqual(
            try file.setCompletion(id: todo.id, targetState: true, expectedRevision: 0).disposition,
            .changed
        )
        let bytesAfterFirstRequest = try Data(contentsOf: file.fileURL)

        let repeated = try file.setCompletion(id: todo.id, targetState: true, expectedRevision: 0)

        XCTAssertEqual(repeated.disposition, .alreadyAtTarget)
        XCTAssertEqual(repeated.canonicalState.todos[0].completionRevision, 1)
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytesAfterFirstRequest)
    }

    func testStaleConflictingRequestDoesNotWriteOrChangeState() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Stale request")
        try file.save(StickyAppState(todos: [todo]))
        _ = try file.setCompletion(id: todo.id, targetState: true, expectedRevision: 0)
        let bytesBeforeStaleRequest = try Data(contentsOf: file.fileURL)

        let stale = try file.setCompletion(id: todo.id, targetState: false, expectedRevision: 0)

        XCTAssertEqual(stale.disposition, .staleConflict)
        XCTAssertTrue(stale.canonicalState.todos[0].isCompleted)
        XCTAssertEqual(stale.canonicalState.todos[0].completionRevision, 1)
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytesBeforeStaleRequest)
    }

    func testMissingTodoDoesNotChangePersistedState() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try file.save(StickyAppState(todos: [TodoItem(title: "Existing")]))
        let bytesBeforeRequest = try Data(contentsOf: file.fileURL)

        let missing = try file.setCompletion(id: UUID(), targetState: true, expectedRevision: 0)

        XCTAssertEqual(missing.disposition, .notFound)
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytesBeforeRequest)
    }

    func testConcurrentCompletionMutationsPreserveUnrelatedTodos() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todoA = TodoItem(title: "Todo A")
        let todoB = TodoItem(title: "Todo B")
        try file.save(StickyAppState(todos: [todoA, todoB]))
        let errors = MutationErrorBox()

        DispatchQueue.concurrentPerform(iterations: 2) { index in
            let todo = index == 0 ? todoA : todoB
            do {
                let result = try file.setCompletion(
                    id: todo.id,
                    targetState: true,
                    expectedRevision: todo.completionRevision
                )
                guard result.disposition == .changed else {
                    errors.append(TestMutationError.noMutation)
                    return
                }
            } catch {
                errors.append(error)
            }
        }

        XCTAssertTrue(errors.errors.isEmpty, "Unexpected mutation errors: \(errors.errors)")
        let finalState = try file.load()
        XCTAssertEqual(finalState.todos.count, 2)
        XCTAssertTrue(finalState.todos.allSatisfy(\.isCompleted))
        XCTAssertTrue(finalState.todos.allSatisfy { $0.completionRevision == 1 })
    }

    func testTitleEditsDoNotIncrementCompletionRevision() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let revisions = await MainActor.run { () -> (Int, Int, Int) in
            let store = TodoStore(file: file)
            store.addTodo(title: "Before")
            let id = store.todos[0].id
            let initialRevision = store.todos[0].completionRevision
            store.updateTodoTitle(id: id, title: "After title edit")
            let afterTitleEdit = store.todos[0].completionRevision
            store.toggleTodo(id: id)
            store.updateTodoTitle(id: id, title: "Completed title edit")
            return (initialRevision, afterTitleEdit, store.todos[0].completionRevision)
        }

        XCTAssertEqual(revisions.0, 0)
        XCTAssertEqual(revisions.1, 0)
        XCTAssertEqual(revisions.2, 1)
        XCTAssertEqual(try file.load().todos.first?.completionRevision, 1)
    }

    func testCompletionMutationPreservesMalformedPersistedBytes() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data("not valid state".utf8)
        try original.write(to: file.fileURL)

        XCTAssertThrowsError(try file.setCompletion(id: UUID(), targetState: true, expectedRevision: 0))
        XCTAssertEqual(try Data(contentsOf: file.fileURL), original)
    }

    func testNegativePersistedCompletionRevisionFailsClosed() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let invalidJSON = """
        {"todos":[{"id":"\(id.uuidString)","title":"Invalid revision","isCompleted":false,"completionRevision":-1,"createdAt":0}],"selectedColor":"yellow"}
        """
        let original = Data(invalidJSON.utf8)
        try original.write(to: file.fileURL)

        XCTAssertThrowsError(try file.setCompletion(id: id, targetState: true, expectedRevision: 0))
        XCTAssertEqual(try Data(contentsOf: file.fileURL), original)
    }

    func testCompletionRevisionOverflowFailsWithoutChangingPersistedState() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Maximum revision")
        try file.save(StickyAppState(todos: [todo]))
        _ = try file.mutate { state in
            state.todos[0].completionRevision = Int.max
            return true
        }
        let bytesAtMaximum = try Data(contentsOf: file.fileURL)

        XCTAssertThrowsError(
            try file.setCompletion(id: todo.id, targetState: true, expectedRevision: Int.max)
        ) { error in
            XCTAssertEqual(error as? TodoStateFileError, .completionRevisionOverflow)
        }
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytesAtMaximum)
        XCTAssertEqual(try file.load().todos[0].completionRevision, Int.max)
        XCTAssertFalse(try file.load().todos[0].isCompleted)
    }

    func testCompletionPersistenceFailurePreservesCanonicalAndTodoStoreState() async throws {
        let (canonicalFile, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(
            title: "Persist only on success",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let originalState = StickyAppState(todos: [todo])
        try canonicalFile.save(originalState)
        let originalBytes = try Data(contentsOf: canonicalFile.fileURL)
        let failingFile = TodoStateFile(fileURL: canonicalFile.fileURL) { _, _ in
            throw TestPersistenceError.writeFailed
        }

        XCTAssertThrowsError(
            try failingFile.setCompletion(id: todo.id, targetState: true, expectedRevision: 0)
        ) { error in
            XCTAssertEqual(error as? TestPersistenceError, .writeFailed)
        }
        XCTAssertEqual(try Data(contentsOf: canonicalFile.fileURL), originalBytes)
        XCTAssertEqual(try canonicalFile.load(), originalState)

        let storeResult = await MainActor.run { () -> (Bool, Bool, Bool?, Int?) in
            let store = TodoStore(file: failingFile)
            let toggled = store.toggleTodo(id: todo.id)
            return (
                toggled,
                store.isPersistenceErrorPresented,
                store.todos.first?.isCompleted,
                store.todos.first?.completionRevision
            )
        }

        XCTAssertFalse(storeResult.0, "TodoStore must not report a failed persistence as success.")
        XCTAssertTrue(storeResult.1, "TodoStore should surface its existing generic persistence error.")
        XCTAssertEqual(storeResult.2, false)
        XCTAssertEqual(storeResult.3, 0)
        XCTAssertEqual(try Data(contentsOf: canonicalFile.fileURL), originalBytes)
        XCTAssertEqual(try canonicalFile.load(), originalState)
    }

    func testTodoReferencePreservesUUIDWithoutDependingOnTitle() {
        let id = UUID()
        let firstTodo = TodoItem(id: id, title: "First title")
        let renamedTodo = TodoItem(id: id, title: "Renamed title")
        let firstReference = TodoReference(id: firstTodo.id)
        let renamedReference = TodoReference(id: renamedTodo.id)

        XCTAssertEqual(firstReference.id, id)
        XCTAssertEqual(firstReference, renamedReference)
        XCTAssertEqual(firstReference.displayRepresentation, renamedReference.displayRepresentation)
    }

    func testTodoReferenceQueryDoesNotSuggestTodos() async throws {
        let suggestions = try await TodoReferenceQuery().suggestedEntities()
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testWidgetCompletionIntentUsesRenderedIdentityTargetAndRevision() {
        var firstTodo = TodoItem(id: UUID(), title: "First")
        firstTodo.completionRevision = 3
        var secondTodo = TodoItem(id: UUID(), title: "Second")
        secondTodo.completionRevision = 8

        let firstIntent = WidgetCompletionIntentFactory.completionIntent(for: firstTodo)
        let secondIntent = WidgetCompletionIntentFactory.completionIntent(for: secondTodo)

        XCTAssertEqual(firstIntent.todo.id, firstTodo.id)
        XCTAssertTrue(firstIntent.targetState)
        XCTAssertEqual(firstIntent.expectedRevision, 3)
        XCTAssertEqual(secondIntent.todo.id, secondTodo.id)
        XCTAssertTrue(secondIntent.targetState)
        XCTAssertEqual(secondIntent.expectedRevision, 8)
    }

    func testCompletionIntentExecutesCanonicalTransition() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Intent completion")
        try file.save(StickyAppState(todos: [todo]))
        let intent = SetTodoCompletionIntent(
            todo: TodoReference(id: todo.id),
            targetState: true,
            expectedRevision: 0
        )

        XCTAssertEqual(try intent.execute(using: file), .changed)
        XCTAssertTrue(try file.load().todos[0].isCompleted)
        XCTAssertEqual(try file.load().todos[0].completionRevision, 1)
    }

    func testCompletionIntentDuplicateIsIdempotent() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Intent duplicate")
        try file.save(StickyAppState(todos: [todo]))
        let intent = SetTodoCompletionIntent(
            todo: TodoReference(id: todo.id),
            targetState: true,
            expectedRevision: 0
        )

        XCTAssertEqual(try intent.execute(using: file), .changed)
        let bytesAfterFirstRequest = try Data(contentsOf: file.fileURL)
        XCTAssertEqual(try intent.execute(using: file), .alreadyAtTarget)
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytesAfterFirstRequest)
        XCTAssertEqual(try file.load().todos[0].completionRevision, 1)
    }

    func testCompletionIntentRejectsStaleConflict() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Intent conflict")
        try file.save(StickyAppState(todos: [todo]))
        _ = try file.setCompletion(id: todo.id, targetState: true, expectedRevision: 0)
        let canonicalBytes = try Data(contentsOf: file.fileURL)
        let staleIntent = SetTodoCompletionIntent(
            todo: TodoReference(id: todo.id),
            targetState: false,
            expectedRevision: 0
        )

        XCTAssertThrowsError(try staleIntent.execute(using: file)) { error in
            XCTAssertEqual(error as? TodoCompletionIntentError, .staleConflict)
        }
        XCTAssertEqual(try Data(contentsOf: file.fileURL), canonicalBytes)
        XCTAssertTrue(try file.load().todos[0].isCompleted)
        XCTAssertEqual(try file.load().todos[0].completionRevision, 1)
    }

    func testCompletionIntentRejectsMissingTodoWithoutCreatingOne() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try file.save(StickyAppState(todos: [TodoItem(title: "Existing")]))
        let canonicalBytes = try Data(contentsOf: file.fileURL)
        let intent = SetTodoCompletionIntent(
            todo: TodoReference(id: UUID()),
            targetState: true,
            expectedRevision: 0
        )

        XCTAssertThrowsError(try intent.execute(using: file)) { error in
            XCTAssertEqual(error as? TodoCompletionIntentError, .notFound)
        }
        XCTAssertEqual(try Data(contentsOf: file.fileURL), canonicalBytes)
        XCTAssertEqual(try file.load().todos.count, 1)
    }

    func testCompletionIntentRejectsNegativeExpectedRevision() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Invalid intent revision")
        try file.save(StickyAppState(todos: [todo]))
        let canonicalBytes = try Data(contentsOf: file.fileURL)
        let intent = SetTodoCompletionIntent(
            todo: TodoReference(id: todo.id),
            targetState: true,
            expectedRevision: -1
        )

        XCTAssertThrowsError(try intent.execute(using: file)) { error in
            XCTAssertEqual(error as? TodoCompletionIntentError, .invalidExpectedRevision)
        }
        XCTAssertEqual(try Data(contentsOf: file.fileURL), canonicalBytes)
        XCTAssertFalse(try file.load().todos[0].isCompleted)
    }

    func testCompletionIntentPreservesCorruptCanonicalState() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let corruptBytes = Data("not valid state".utf8)
        try corruptBytes.write(to: file.fileURL)
        let intent = SetTodoCompletionIntent(
            todo: TodoReference(id: UUID()),
            targetState: true,
            expectedRevision: 0
        )

        XCTAssertThrowsError(try intent.execute(using: file)) { error in
            XCTAssertEqual(error as? TodoCompletionIntentError, .storageUnavailable)
        }
        XCTAssertEqual(try Data(contentsOf: file.fileURL), corruptBytes)
    }

    func testCompletionIntentReportsPersistenceFailureWithoutChangingCanonicalState() throws {
        let (canonicalFile, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let todo = TodoItem(title: "Intent write failure")
        try canonicalFile.save(StickyAppState(todos: [todo]))
        let canonicalBytes = try Data(contentsOf: canonicalFile.fileURL)
        let failingFile = TodoStateFile(fileURL: canonicalFile.fileURL) { _, _ in
            throw TestPersistenceError.writeFailed
        }
        let intent = SetTodoCompletionIntent(
            todo: TodoReference(id: todo.id),
            targetState: true,
            expectedRevision: 0
        )

        XCTAssertThrowsError(try intent.execute(using: failingFile)) { error in
            XCTAssertEqual(error as? TodoCompletionIntentError, .storageUnavailable)
        }
        XCTAssertEqual(try Data(contentsOf: canonicalFile.fileURL), canonicalBytes)
        XCTAssertFalse(try canonicalFile.load().todos[0].isCompleted)
        XCTAssertEqual(try canonicalFile.load().todos[0].completionRevision, 0)
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

    func testSharedMigrationCopiesValidLegacyStateWithoutChangingBytes() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = TodoStateFile(fileURL: directory.appending(path: "legacy/todo-state.json"))
        let sharedFile = TodoStateFile(fileURL: directory.appending(path: "shared/todo-state.json"))
        let expected = StickyAppState(
            todos: [TodoItem(
                title: "Migrate me",
                isCompleted: true,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000.123456)
            )],
            selectedColor: .purple
        )

        try legacyFile.save(expected)
        let legacyBytes = try Data(contentsOf: legacyFile.fileURL)

        XCTAssertTrue(try sharedFile.migrateIfNeeded(from: legacyFile))
        XCTAssertEqual(try Data(contentsOf: sharedFile.fileURL), legacyBytes)
        XCTAssertEqual(try sharedFile.load(), expected)
    }

    func testSharedMigrationNeverOverwritesExistingSharedState() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = TodoStateFile(fileURL: directory.appending(path: "legacy/todo-state.json"))
        let sharedFile = TodoStateFile(fileURL: directory.appending(path: "shared/todo-state.json"))
        let legacyState = StickyAppState(todos: [TodoItem(
            title: "Legacy",
            createdAt: Date(timeIntervalSince1970: 1_700_000_001.25)
        )])
        let sharedState = StickyAppState(
            todos: [TodoItem(
                title: "Canonical",
                createdAt: Date(timeIntervalSince1970: 1_700_000_002.5)
            )],
            selectedColor: .blue
        )

        try legacyFile.save(legacyState)
        try sharedFile.save(sharedState)

        XCTAssertFalse(try sharedFile.migrateIfNeeded(from: legacyFile))
        XCTAssertEqual(try sharedFile.load(), sharedState)
    }

    func testCorruptLegacyDataIsPreservedAndNotMigrated() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = TodoStateFile(fileURL: directory.appending(path: "legacy/todo-state.json"))
        let sharedFile = TodoStateFile(fileURL: directory.appending(path: "shared/todo-state.json"))
        let corruptData = Data("not valid state".utf8)
        try FileManager.default.createDirectory(
            at: legacyFile.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try corruptData.write(to: legacyFile.fileURL, options: .atomic)

        XCTAssertThrowsError(try sharedFile.migrateIfNeeded(from: legacyFile))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sharedFile.fileURL.path))
        XCTAssertEqual(try Data(contentsOf: legacyFile.fileURL), corruptData)
    }

    func testStoreMutationReadsLatestStateBeforeWriting() async throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await MainActor.run { () -> ([String], [String]) in
            let firstStore = TodoStore(file: file)
            let secondStore = TodoStore(file: file)

            XCTAssertTrue(firstStore.addTodo(title: "First"))
            XCTAssertTrue(secondStore.addTodo(title: "Second"))

            return (
                TodoStore(file: file).todos.map(\.title),
                secondStore.todos.map(\.title)
            )
        }

        XCTAssertEqual(Set(result.0), Set(["First", "Second"]))
        XCTAssertEqual(Set(result.1), Set(["First", "Second"]))
    }

    func testConcurrentMutationsSerializeReadModifyWrite() throws {
        let (file, directory) = try Self.makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: directory) }

        let errorBox = MutationErrorBox()
        let mutationCount = 24

        DispatchQueue.concurrentPerform(iterations: mutationCount) { index in
            do {
                guard try file.mutate({ state in
                    state.todos.append(TodoItem(
                        title: "Concurrent \(index)",
                        createdAt: Date(timeIntervalSince1970: Double(index))
                    ))
                    return true
                }) != nil else {
                    errorBox.append(TestMutationError.noMutation)
                    return
                }
            } catch {
                errorBox.append(error)
            }
        }

        XCTAssertTrue(errorBox.errors.isEmpty, "Unexpected mutation errors: \(errorBox.errors)")
        XCTAssertEqual(try file.load().todos.count, mutationCount)
    }

    private static func makeTemporaryFile() throws -> (TodoStateFile, URL) {
        let directory = try makeTemporaryDirectory()
        return (TodoStateFile(fileURL: directory.appending(path: "state.json")), directory)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TodoStickyTests.\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

private final class MutationErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var errors: [Error] = []

    func append(_ error: Error) {
        lock.lock()
        errors.append(error)
        lock.unlock()
    }
}

private enum TestMutationError: Error {
    case noMutation
}

private enum TestPersistenceError: Error, Equatable {
    case writeFailed
}
