import Foundation

struct TodoStateFile: Sendable {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func applicationSupport() throws -> TodoStateFile {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = supportDirectory.appending(path: "TodoSticky", directoryHint: .isDirectory)
        return TodoStateFile(fileURL: appDirectory.appending(path: "todo-state.json"))
    }

    func load() throws -> StickyAppState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StickyAppState()
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(StickyAppState.self, from: data)
    }

    func save(_ state: StickyAppState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
