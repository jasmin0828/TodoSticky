import SwiftUI

struct StickyView: View {
    @Bindable var store: TodoStore
    @State private var draft = ""
    @State private var editingTodoID: UUID? = nil
    @State private var editingTodoDraft = ""

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 280

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(store.selectedColor.color)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(8)
                    .ignoresSafeArea(.container, edges: .top)

                VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                    StickyHeader(
                        selectedColor: store.selectedColor,
                        onSelectColor: { store.selectColor($0) }
                    )
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
            isEditing: editingTodoID == item.id,
            editingDraft: $editingTodoDraft,
            onBeginEditing: { beginEditing(item) },
            onCommitEditing: { commitEditing(id: item.id, title: $0) },
            onCancelEditing: { cancelEditing(id: item.id) },
            onToggle: { store.toggleTodo(id: item.id) },
            onDelete: { store.deleteTodo(id: item.id) }
        )
    }

    private func beginEditing(_ item: TodoItem) {
        if let editingTodoID, editingTodoID != item.id {
            store.updateTodoTitle(id: editingTodoID, title: editingTodoDraft)
        }

        editingTodoID = item.id
        editingTodoDraft = item.title
    }

    private func commitEditing(id: UUID, title: String) {
        guard editingTodoID == id else { return }
        store.updateTodoTitle(id: id, title: title)
        editingTodoID = nil
        editingTodoDraft = ""
    }

    private func cancelEditing(id: UUID) {
        guard editingTodoID == id else { return }
        editingTodoID = nil
        editingTodoDraft = ""
    }

    private func addTodo() {
        guard store.addTodo(title: draft) else { return }
        draft = ""
    }
}
