import AppIntents
import Foundation

struct TodoReference: AppEntity, Equatable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Todo" }
    static var defaultQuery: TodoReferenceQuery { TodoReferenceQuery() }

    let id: UUID

    var displayRepresentation: DisplayRepresentation { "Todo" }

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
            "The expected completion revision is invalid."
        case .staleConflict:
            "This Todo changed before the action could complete."
        case .notFound:
            "This Todo is no longer available."
        case .storageUnavailable:
            "Todo state is unavailable."
        }
    }
}

struct SetTodoCompletionIntent: AppIntent {
    static var title: LocalizedStringResource { "Set Todo Completion" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Todo") var todo: TodoReference
    @Parameter(title: "Completed") var targetState: Bool
    @Parameter(title: "Expected Revision") var expectedRevision: Int

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

        _ = try execute(using: stateFile)
        return .result()
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
