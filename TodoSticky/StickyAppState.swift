import Foundation

struct StickyAppState: Codable, Equatable, Sendable {
    var todos: [TodoItem] = []
    var selectedColor: StickyColor = .yellow
}
