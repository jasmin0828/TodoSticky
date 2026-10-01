import Foundation

struct TodoItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var completionRevision: Int
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted
        case completionRevision
        case createdAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completionRevision = 0
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        if container.contains(.completionRevision) {
            completionRevision = try container.decode(Int.self, forKey: .completionRevision)
        } else {
            completionRevision = 0
        }

        guard completionRevision >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .completionRevision,
                in: container,
                debugDescription: "Todo completion revision must be non-negative."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        guard completionRevision >= 0 else {
            throw EncodingError.invalidValue(
                completionRevision,
                EncodingError.Context(
                    codingPath: encoder.codingPath + [CodingKeys.completionRevision],
                    debugDescription: "Todo completion revision must be non-negative."
                )
            )
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(completionRevision, forKey: .completionRevision)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
