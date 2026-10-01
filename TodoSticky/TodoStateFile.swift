import Darwin
import Foundation

enum TodoStateFileError: LocalizedError, Equatable, Sendable {
    case sharedContainerUnavailable(String)
    case unableToOpenLock(path: String, errno: Int32)
    case unableToAcquireLock(path: String, errno: Int32)
    case invalidExpectedCompletionRevision
    case completionRevisionOverflow

    var errorDescription: String? {
        switch self {
        case .sharedContainerUnavailable:
            "The shared container is unavailable."
        case let .unableToOpenLock(_, error):
            "Unable to open storage lock (errno \(error))."
        case let .unableToAcquireLock(_, error):
            "Unable to acquire storage lock (errno \(error))."
        case .invalidExpectedCompletionRevision:
            "The expected completion revision is invalid."
        case .completionRevisionOverflow:
            "The completion revision cannot be incremented."
        }
    }
}

enum TodoCompletionMutationDisposition: Equatable, Sendable {
    case changed
    case alreadyAtTarget
    case notFound
    case staleConflict
}

struct TodoCompletionMutationResult: Equatable, Sendable {
    let disposition: TodoCompletionMutationDisposition
    let canonicalState: StickyAppState
}

struct TodoStateFile: Sendable {
    static let applicationGroupIdentifier = "group.com.jasminstudio.TodoSticky"

    let fileURL: URL
    private let persistenceWriter: @Sendable (Data, URL) throws -> Void

    init(fileURL: URL) {
        self.fileURL = fileURL
        persistenceWriter = Self.writeAtomically
    }

    init(fileURL: URL, persistenceWriter: @escaping @Sendable (Data, URL) throws -> Void) {
        self.fileURL = fileURL
        self.persistenceWriter = persistenceWriter
    }

    static func applicationSupport() throws -> TodoStateFile {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let appDirectory = supportDirectory.appending(path: "TodoSticky", directoryHint: .isDirectory)
        return TodoStateFile(fileURL: appDirectory.appending(path: "todo-state.json"))
    }

    static func applicationGroup() throws -> TodoStateFile {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: applicationGroupIdentifier
        ) else {
            throw TodoStateFileError.sharedContainerUnavailable(applicationGroupIdentifier)
        }

        let appDirectory = containerURL.appending(path: "TodoSticky", directoryHint: .isDirectory)
        return TodoStateFile(fileURL: appDirectory.appending(path: "todo-state.json"))
    }

    func load() throws -> StickyAppState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StickyAppState()
        }

        return try decode(Data(contentsOf: fileURL))
    }

    func save(_ state: StickyAppState) throws {
        try withExclusiveLock {
            try write(try encode(state))
        }
    }

    @discardableResult
    func mutate(_ mutation: (inout StickyAppState) throws -> Bool) throws -> StickyAppState? {
        try withExclusiveLock {
            var state = try load()
            guard try mutation(&state) else { return nil }
            try write(try encode(state))
            return state
        }
    }

    func setCompletion(
        id: UUID,
        targetState: Bool,
        expectedRevision: Int
    ) throws -> TodoCompletionMutationResult {
        guard expectedRevision >= 0 else {
            throw TodoStateFileError.invalidExpectedCompletionRevision
        }

        var disposition: TodoCompletionMutationDisposition = .notFound
        var canonicalState: StickyAppState?

        _ = try mutate { state in
            canonicalState = state
            guard let index = state.todos.firstIndex(where: { $0.id == id }) else {
                disposition = .notFound
                return false
            }

            let todo = state.todos[index]
            guard todo.completionRevision == expectedRevision else {
                disposition = todo.isCompleted == targetState ? .alreadyAtTarget : .staleConflict
                return false
            }

            guard todo.isCompleted != targetState else {
                disposition = .alreadyAtTarget
                return false
            }

            guard todo.completionRevision < Int.max else {
                throw TodoStateFileError.completionRevisionOverflow
            }

            state.todos[index].isCompleted = targetState
            state.todos[index].completionRevision += 1
            disposition = .changed
            canonicalState = state
            return true
        }

        guard let canonicalState else {
            preconditionFailure("A state mutation must evaluate the canonical state.")
        }
        return TodoCompletionMutationResult(
            disposition: disposition,
            canonicalState: canonicalState
        )
    }

    /// Copies a valid legacy state into the shared container exactly once.
    /// An existing shared file always wins and is never overwritten.
    @discardableResult
    func migrateIfNeeded(from legacyFile: TodoStateFile) throws -> Bool {
        try withExclusiveLock {
            guard !FileManager.default.fileExists(atPath: fileURL.path) else {
                return false
            }
            guard FileManager.default.fileExists(atPath: legacyFile.fileURL.path) else {
                return false
            }

            let legacyData = try Data(contentsOf: legacyFile.fileURL)
            _ = try decode(legacyData)
            try write(legacyData)
            return true
        }
    }

    private func encode(_ state: StickyAppState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    private func decode(_ data: Data) throws -> StickyAppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(StickyAppState.self, from: data)
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try persistenceWriter(data, fileURL)
    }

    private static func writeAtomically(_ data: Data, _ fileURL: URL) throws {
        try data.write(to: fileURL, options: .atomic)
    }

    private func withExclusiveLock<T>(_ body: () throws -> T) throws -> T {
        let lockURL = fileURL.appendingPathExtension("lock")
        try FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let lock = try TodoStateFileLock(url: lockURL)
        try lock.acquire()
        defer { lock.release() }
        return try body()
    }
}

private final class TodoStateFileLock {
    private let descriptor: Int32
    private let path: String

    init(url: URL) throws {
        path = url.path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw TodoStateFileError.unableToOpenLock(path: path, errno: errno)
        }
        self.descriptor = descriptor
    }

    func acquire() throws {
        while flock(descriptor, LOCK_EX) != 0 {
            let lockError = errno
            if lockError == EINTR { continue }
            throw TodoStateFileError.unableToAcquireLock(path: path, errno: lockError)
        }
    }

    func release() {
        _ = flock(descriptor, LOCK_UN)
    }

    deinit {
        release()
        _ = Darwin.close(descriptor)
    }
}
