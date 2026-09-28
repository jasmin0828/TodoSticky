import SwiftUI

struct StickyView: View {
    @Bindable var store: TodoStore
    @State private var draft = ""

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 280

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(store.selectedColor.color)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(8)

                VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                    StickyHeader(selectedColor: store.selectedColor) { color in
                        store.selectColor(color)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)

                    TodoInputView(draft: $draft, compact: compact, onSubmit: addTodo)

                    if !compact {
                        Divider()
                            .overlay(.black.opacity(0.12))
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(store.openTodos) { item in
                                todoRow(item, compact: compact)
                            }

                            if !compact, !store.completedTodos.isEmpty {
                                Text("已完成事项")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.4)
                                    .foregroundStyle(.black.opacity(0.42))
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)

                                ForEach(store.completedTodos) { item in
                                    todoRow(item, compact: compact)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.automatic)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
        }
        .frame(minWidth: 320, minHeight: 180)
        .preferredColorScheme(.light)
        .alert("无法保存数据", isPresented: $store.isPersistenceErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(store.persistenceErrorMessage ?? "本地存储不可用。")
        }
    }

    private func todoRow(_ item: TodoItem, compact: Bool) -> some View {
        TodoRowView(
            item: item,
            compact: compact,
            onToggle: { store.toggleTodo(id: item.id) },
            onDelete: { store.deleteTodo(id: item.id) }
        )
    }

    private func addTodo() {
        guard store.addTodo(title: draft) else { return }
        draft = ""
    }
}
