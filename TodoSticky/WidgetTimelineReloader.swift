import WidgetKit

@MainActor
enum WidgetTimelineReloader {
    static func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
