import SwiftUI

struct TodoRowView: View {
    let item: TodoItem
    let compact: Bool
    let isEditing: Bool
    @Binding var editingDraft: String
    let onBeginEditing: (String) -> Void
    let onCommitEditing: (String) -> Void
    let onCancelEditing: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isCancellingEdit = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.isCompleted ? .black.opacity(0.48) : .black.opacity(0.58))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title)
            .accessibilityValue(item.isCompleted ? Text("todo.status.completed") : Text("todo.status.open"))

            if isEditing {
                TextField("", text: $editingDraft)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(item.isCompleted ? 0.42 : 0.76))
                    .strikethrough(item.isCompleted, color: .black.opacity(0.35))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isEditorFocused)
                    .accessibilityLabel(Text("todo.edit.accessibility"))
                    .accessibilityHint(Text("todo.edit.hint"))
                    .onSubmit(commitEditing)
                    .onExitCommand(perform: cancelEditing)
                    .onChange(of: isEditorFocused) { _, isFocused in
                        #if DEBUG
                        logEditDiagnostic(
                            "focus state todoID=\(item.id) focused=\(isFocused) draft=\(String(reflecting: editingDraft))"
                        )
                        #endif
                        guard !isFocused, isEditing, !isCancellingEdit else { return }
                        commitEditing()
                    }
                    .onAppear {
                        #if DEBUG
                        logEditDiagnostic(
                            "TextField appeared todoID=\(item.id) draft=\(String(reflecting: editingDraft))"
                        )
                        #endif
                    }
                    .task(id: isEditing) {
                        guard isEditing else { return }
                        isCancellingEdit = false
                        #if DEBUG
                        logEditDiagnostic("focus request todoID=\(item.id)")
                        #endif
                        isEditorFocused = true
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(item.isCompleted ? 0.42 : 0.76))
                    .strikethrough(item.isCompleted, color: .black.opacity(0.35))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .overlay {
                        TodoTitleDoubleClickSurface(todoID: item.id) { clickedID in
                            guard clickedID == item.id else { return }
                            onBeginEditing("native-double-click")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                        .accessibilityHidden(true)
                    }
                    .accessibilityAction(named: Text("todo.edit.accessibility")) {
                        onBeginEditing("accessibility")
                    }
            }

            Spacer(minLength: 0)

            if isHovered {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.52))
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("todo.delete.accessibility"))
                .accessibilityValue(Text(item.title))
                .transition(.opacity)
            }
        }
        .padding(.vertical, compact ? 1 : 3)
        .contentShape(.rect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        #if DEBUG
        .onChange(of: isEditing) { wasEditing, isEditing in
            let previousView = wasEditing ? "TextField" : "Text"
            let currentView = isEditing ? "TextField" : "Text"
            logEditDiagnostic(
                "row render transition todoID=\(item.id) view=\(previousView)->\(currentView) draft=\(String(reflecting: editingDraft))"
            )
        }
        #endif
    }

    private func commitEditing() {
        onCommitEditing(editingDraft)
    }

    private func cancelEditing() {
        guard isEditing else { return }
        isCancellingEdit = true
        isEditorFocused = false
        onCancelEditing()
    }

    #if DEBUG
    private func logEditDiagnostic(_ message: String) {
        FileHandle.standardError.write(Data("TodoSticky DEBUG: edit \(message)\n".utf8))
    }
    #endif
}
