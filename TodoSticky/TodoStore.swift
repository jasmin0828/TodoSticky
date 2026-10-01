import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class TodoStore {
    private var state = StickyAppState()
    private(set) var persistenceErrorMessage: String?
    var isPersistenceErrorPresented = false

    @ObservationIgnored private let stateFile: TodoStateFile?
    @ObservationIgnored private var canWriteState = true

    var todos: [TodoItem] { state.todos }
    var selectedColor: StickyColor { state.selectedColor }
    var openTodos: [TodoItem] { orderedTodos(completed: false) }
    var completedTodos: [TodoItem] { orderedTodos(completed: true) }

    init(file: TodoStateFile) {
        stateFile = file

        do {
            state = try file.load()
        } catch {
            canWriteState = false
            showPersistenceError(String(localized: "error.todo.readFailure"))
        }
    }

    private init(storageUnavailableMessage: String) {
        stateFile = nil
        canWriteState = false
        showPersistenceError(storageUnavailableMessage)
    }

    static func applicationStore() -> TodoStore {
        do {
            let sharedFile = try TodoStateFile.applicationGroup()
            let legacyFile = try TodoStateFile.applicationSupport()
            try sharedFile.migrateIfNeeded(from: legacyFile)
            return TodoStore(file: sharedFile)
        } catch {
            return TodoStore(storageUnavailableMessage: String(localized: "error.todo.sharedMigrationFailure"))
        }
    }

    @discardableResult
    func addTodo(title: String, createdAt: Date = .now) -> Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return false }

        return commit { state in
            state.todos.append(TodoItem(title: cleanedTitle, createdAt: createdAt))
            return true
        }
    }

    @discardableResult
    func toggleTodo(id: UUID) -> Bool {
        guard canWriteState,
              let stateFile,
              let todo = state.todos.first(where: { $0.id == id }) else {
            return false
        }

        do {
            let result = try stateFile.setCompletion(
                id: id,
                targetState: !todo.isCompleted,
                expectedRevision: todo.completionRevision
            )
            state = result.canonicalState

            switch result.disposition {
            case .changed:
                clearPersistenceError()
                WidgetCenter.shared.reloadTimelines(ofKind: "TodoStickyWidget")
                return true
            case .alreadyAtTarget:
                clearPersistenceError()
                return true
            case .notFound, .staleConflict:
                return false
            }
        } catch {
            showPersistenceError(String(localized: "error.todo.saveFailure"))
            return false
        }
    }

    @discardableResult
    func updateTodoTitle(id: UUID, title: String) -> Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return false }

        return commit { state in
            guard let index = state.todos.firstIndex(where: { $0.id == id }) else { return false }
            state.todos[index].title = cleanedTitle
            return true
        }
    }

    @discardableResult
    func deleteTodo(id: UUID) -> Bool {
        commit { state in
            guard let index = state.todos.firstIndex(where: { $0.id == id }) else { return false }
            state.todos.remove(at: index)
            return true
        }
    }

    func selectColor(_ color: StickyColor) {
        _ = commit { state in
            guard state.selectedColor != color else { return false }
            state.selectedColor = color
            return true
        }
    }

    @discardableResult
    func reloadFromDisk() -> Bool {
        guard let stateFile else { return false }

        do {
            state = try stateFile.load()
            canWriteState = true
            persistenceErrorMessage = nil
            isPersistenceErrorPresented = false
            return true
        } catch {
            canWriteState = false
            showPersistenceError(String(localized: "error.todo.readFailure"))
            return false
        }
    }

    private func orderedTodos(completed: Bool) -> [TodoItem] {
        state.todos.enumerated()
            .filter { $0.element.isCompleted == completed }
            .sorted {
                if $0.element.createdAt == $1.element.createdAt {
                    return $0.offset < $1.offset
                }
                return $0.element.createdAt > $1.element.createdAt
            }
            .map(\.element)
    }

    private func commit(_ mutation: (inout StickyAppState) -> Bool) -> Bool {
        guard canWriteState, let stateFile else { return false }

        do {
            guard let updatedState = try stateFile.mutate(mutation) else {
                return false
            }
            state = updatedState
            clearPersistenceError()
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoStickyWidget")
            return true
        } catch {
            showPersistenceError(String(localized: "error.todo.saveFailure"))
            return false
        }
    }

    private func showPersistenceError(_ message: String) {
        persistenceErrorMessage = message
        isPersistenceErrorPresented = true
    }

    private func clearPersistenceError() {
        persistenceErrorMessage = nil
        isPersistenceErrorPresented = false
    }
}
