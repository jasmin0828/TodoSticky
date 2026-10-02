import SwiftUI
import WidgetKit

struct TodoStickyWidgetEntry: TimelineEntry {
    let date: Date
    let state: StickyAppState
    let storageError: Bool
    let isPlaceholder: Bool

    init(
        date: Date,
        state: StickyAppState,
        storageError: Bool,
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.state = state
        self.storageError = storageError
        self.isPlaceholder = isPlaceholder
    }

    var openTodos: [TodoItem] {
        state.todos
            .enumerated()
            .filter { !$0.element.isCompleted }
            .sorted {
                if $0.element.createdAt == $1.element.createdAt {
                    return $0.offset < $1.offset
                }
                return $0.element.createdAt > $1.element.createdAt
            }
            .map(\.element)
    }

    static let placeholder = TodoStickyWidgetEntry(
        date: .now,
        state: StickyAppState(todos: [
            TodoItem(title: "widget.placeholder.planTheDay"),
            TodoItem(title: "widget.placeholder.reviewTodoSticky")
        ]),
        storageError: false,
        isPlaceholder: true
    )
}

struct TodoStickyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoStickyWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoStickyWidgetEntry) -> Void) {
        completion(loadEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoStickyWidgetEntry>) -> Void) {
        let now = Date.now
        let entry = loadEntry(date: now)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry(date: Date) -> TodoStickyWidgetEntry {
        do {
            let stateFile = try TodoStateFile.applicationGroup()
            return TodoStickyWidgetEntry(
                date: date,
                state: try stateFile.load(),
                storageError: false
            )
        } catch {
            return TodoStickyWidgetEntry(
                date: date,
                state: StickyAppState(),
                storageError: true
            )
        }
    }
}

struct TodoStickyWidgetView: View {
    let entry: TodoStickyWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var effectiveLocale: Locale {
        AppLocaleResolver.appGroupLocale()
    }

    private var visibleTodos: ArraySlice<TodoItem> {
        let limit = family == .systemSmall ? 3 : 5
        return entry.openTodos.prefix(limit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("widget.title")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(entry.openTodos.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if entry.storageError {
                Text("widget.storageUnavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if visibleTodos.isEmpty {
                Text("widget.noOpenTodos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleTodos) { todo in
                    HStack(spacing: 6) {
                        Button(intent: WidgetCompletionIntentFactory.completionIntent(for: todo)) {
                            Image(systemName: "circle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("widget.completeTodo")
                        if entry.isPlaceholder {
                            Text(LocalizedStringKey(todo.title))
                                .font(.caption)
                                .lineLimit(1)
                        } else {
                            Text(verbatim: todo.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.yellow.opacity(0.22)
        }
        .environment(\.locale, effectiveLocale)
    }
}

struct TodoStickyWidget: Widget {
    static let kind = "TodoStickyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodoStickyWidgetProvider()) { entry in
            TodoStickyWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.configurationDisplayName")
        .description("widget.configurationDescription")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TodoStickyWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoStickyWidget()
    }
}
