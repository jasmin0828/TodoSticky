import SwiftUI

struct TodoInputView: View {
    @Binding var draft: String
    let compact: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.black.opacity(0.55))
                .accessibilityHidden(true)

            TextField("添加待办事项…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit(onSubmit)
                .accessibilityLabel("添加待办事项")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, compact ? 7 : 9)
        .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
    }
}
