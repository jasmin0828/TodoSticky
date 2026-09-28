import Foundation

struct WindowFramePreferences {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "stickyWindowFrame") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> StickyWindowFrame? {
        guard let values = defaults.dictionary(forKey: key),
              let x = values["x"] as? Double,
              let y = values["y"] as? Double,
              let width = values["width"] as? Double,
              let height = values["height"] as? Double else {
            return nil
        }
        return StickyWindowFrame(x: x, y: y, width: width, height: height)
    }

    func save(_ frame: StickyWindowFrame) {
        defaults.set(
            ["x": frame.x, "y": frame.y, "width": frame.width, "height": frame.height],
            forKey: key
        )
    }
}
