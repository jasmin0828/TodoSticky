import Foundation

enum WidgetCompletionIntentFactory {
    static func completionIntent(for todo: TodoItem) -> SetTodoCompletionIntent {
        SetTodoCompletionIntent(
            todo: TodoReference(id: todo.id),
            targetState: true,
            expectedRevision: todo.completionRevision
        )
    }
}
