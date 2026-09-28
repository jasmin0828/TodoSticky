import Foundation
import Observation

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
            showPersistenceError("本地数据无法读取；为避免覆盖原文件，本次更改不会保存。")
        }
    }

    private init(storageUnavailableMessage: String) {
        stateFile = nil
        canWriteState = false
        showPersistenceError(storageUnavailableMessage)
    }

    static func applicationStore() -> TodoStore {
        do {
            return TodoStore(file: try TodoStateFile.applicationSupport())
        } catch {
            return TodoStore(storageUnavailableMessage: "本地存储不可用；更改无法持久保存。")
        }
    }

    @discardableResult
    func addTodo(title: String, createdAt: Date = .now) -> Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return false }

        state.todos.append(TodoItem(title: cleanedTitle, createdAt: createdAt))
        persist()
        return true
    }

    @discardableResult
    func toggleTodo(id: UUID) -> Bool {
        guard let index = state.todos.firstIndex(where: { $0.id == id }) else { return false }
        state.todos[index].isCompleted.toggle()
        persist()
        return true
    }

    @discardableResult
    func deleteTodo(id: UUID) -> Bool {
        guard let index = state.todos.firstIndex(where: { $0.id == id }) else { return false }
        state.todos.remove(at: index)
        persist()
        return true
    }

    func selectColor(_ color: StickyColor) {
        guard state.selectedColor != color else { return }
        state.selectedColor = color
        persist()
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

    private func persist() {
        guard canWriteState, let stateFile else { return }

        do {
            try stateFile.save(state)
            persistenceErrorMessage = nil
        } catch {
            showPersistenceError("无法保存本地数据；请检查磁盘空间和文件权限。")
        }
    }

    private func showPersistenceError(_ message: String) {
        persistenceErrorMessage = message
        isPersistenceErrorPresented = true
    }
}
