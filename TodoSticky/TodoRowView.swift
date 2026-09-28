import SwiftUI

struct TodoRowView: View {
    let item: TodoItem
    let compact: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

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
            .accessibilityValue(item.isCompleted ? "已完成" : "未完成")

            Text(item.title)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(item.isCompleted ? 0.42 : 0.76))
                .strikethrough(item.isCompleted, color: .black.opacity(0.35))
                .lineLimit(1)
                .truncationMode(.tail)

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
                .accessibilityLabel("删除待办事项：\(item.title)")
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
    }
}
