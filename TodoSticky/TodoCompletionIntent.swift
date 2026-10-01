import AppIntents
import CoreFoundation
import Foundation

enum TodoStateInvalidation {
    static let name = "com.jasminstudio.TodoSticky.shared-state-changed"

    static func post(name: String = name) {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

struct TodoReference: AppEntity, Equatable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "intent.todo" }
    static var defaultQuery: TodoReferenceQuery { TodoReferenceQuery() }

    let id: UUID

    var displayRepresentation: DisplayRepresentation { "intent.todo" }

    init(id: UUID) {
        self.id = id
    }
}

struct TodoReferenceQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [UUID]) async throws -> [TodoReference] {
        guard !identifiers.isEmpty else { return [] }

        do {
            let state = try TodoStateFile.applicationGroup().load()
            let existingIDs = Set(state.todos.map(\.id))
            return identifiers.filter { existingIDs.contains($0) }.map(TodoReference.init(id:))
        } catch {
            throw TodoCompletionIntentError.storageUnavailable
        }
    }

    func suggestedEntities() async throws -> [TodoReference] {
        []
    }
}

enum TodoCompletionIntentError: LocalizedError, Equatable, Sendable {
    case invalidExpectedRevision
    case staleConflict
    case notFound
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidExpectedRevision:
            String(localized: "error.completion.invalidRevision")
        case .staleConflict:
            String(localized: "error.completion.staleConflict")
        case .notFound:
            String(localized: "error.completion.notFound")
        case .storageUnavailable:
            String(localized: "error.completion.storageUnavailable")
        }
    }
}

struct SetTodoCompletionIntent: AppIntent {
    static var title: LocalizedStringResource { "intent.setTodoCompletion.title" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "intent.todo") var todo: TodoReference
    @Parameter(title: "intent.completed") var targetState: Bool
    @Parameter(title: "intent.expectedRevision") var expectedRevision: Int

    init() {}

    init(todo: TodoReference, targetState: Bool, expectedRevision: Int) {
        self.todo = todo
        self.targetState = targetState
        self.expectedRevision = expectedRevision
    }

    func perform() async throws -> some IntentResult {
        let stateFile: TodoStateFile
        do {
            stateFile = try TodoStateFile.applicationGroup()
        } catch {
            throw TodoCompletionIntentError.storageUnavailable
        }

        _ = try executeAndInvalidate(using: stateFile)
        return .result()
    }

    @discardableResult
    func executeAndInvalidate(
        using stateFile: TodoStateFile,
        signal: () -> Void = { TodoStateInvalidation.post() }
    ) throws -> TodoCompletionMutationDisposition {
        let disposition = try execute(using: stateFile)
        if disposition == .changed {
            signal()
        }
        return disposition
    }

    func execute(using stateFile: TodoStateFile) throws -> TodoCompletionMutationDisposition {
        guard expectedRevision >= 0 else {
            throw TodoCompletionIntentError.invalidExpectedRevision
        }

        let result: TodoCompletionMutationResult
        do {
            result = try stateFile.setCompletion(
                id: todo.id,
                targetState: targetState,
                expectedRevision: expectedRevision
            )
        } catch {
            throw TodoCompletionIntentError.storageUnavailable
        }

        switch result.disposition {
        case .changed, .alreadyAtTarget:
            return result.disposition
        case .staleConflict:
            throw TodoCompletionIntentError.staleConflict
        case .notFound:
            throw TodoCompletionIntentError.notFound
        }
    }
}
