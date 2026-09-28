import SwiftUI

struct TodoItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct StickyView: View {
    @State private var draft = ""
    @State private var items: [TodoItem] = [
        TodoItem(title: "提交 Vita 1.2"),
        TodoItem(title: "检查 Alpha Hunter"),
        TodoItem(title: "准备 Solana Demo"),
        TodoItem(title: "整理 Gate 1 记录", isCompleted: true)
    ]

    private var openItems: [TodoItem] {
        items.filter { !$0.isCompleted }
    }

    private var completedItems: [TodoItem] {
        items.filter(\.isCompleted)
    }

    private var stickyYellow: Color {
        Color(red: 1.0, green: 0.93, blue: 0.58)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(stickyYellow)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("今日待办")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.78))

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.42))
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 20)

                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.black.opacity(0.55))

                    TextField("添加待办事项…", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit(addItem)
                        .accessibilityLabel("添加待办事项")

                    if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: addItem) {
                            Image(systemName: "return")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.black.opacity(0.45))
                        .accessibilityLabel("添加")
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Divider()
                    .overlay(.black.opacity(0.12))
                    .padding(.vertical, 16)

                if !openItems.isEmpty {
                    sectionTitle("进行中")
                    ForEach(openItems) { item in
                        todoRow(item)
                    }
                }

                if !completedItems.isEmpty {
                    sectionTitle("已完成事项")
                        .padding(.top, 14)

                    ForEach(completedItems) { item in
                        todoRow(item)
                    }
                }

                Spacer(minLength: 16)

                Text("\(openItems.count) 个待办")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.48))
            }
            .padding(.top, 42)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .padding(8)
        .frame(minWidth: 320, minHeight: 400)
        .preferredColorScheme(.light)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(.black.opacity(0.42))
            .padding(.bottom, 8)
    }

    private func todoRow(_ item: TodoItem) -> some View {
        Button {
            toggle(item)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.isCompleted ? .black.opacity(0.48) : .black.opacity(0.58))

                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(item.isCompleted ? 0.42 : 0.76))
                    .strikethrough(item.isCompleted, color: .black.opacity(0.35))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isCompleted ? "已完成" : "未完成")
    }

    private func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
    }

    private func addItem() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        items.insert(TodoItem(title: title), at: 0)
        draft = ""
    }
}
