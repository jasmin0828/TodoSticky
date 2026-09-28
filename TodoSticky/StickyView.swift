import AppKit
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
                .padding(8)

            VStack(alignment: .leading, spacing: 0) {
                StickyHeader()
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)

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
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
        }
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
                    .lineLimit(1)
                    .truncationMode(.tail)

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

private struct StickyHeader: NSViewRepresentable {
    func makeNSView(context: Context) -> StickyHeaderView {
        StickyHeaderView()
    }

    func updateNSView(_ nsView: StickyHeaderView, context: Context) {}
}

private final class StickyHeaderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "今日待办")
    private let ellipsisImageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHeader()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHeader()
    }

    private func configureHeader() {
        let systemFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) ?? systemFont.fontDescriptor
        titleLabel.font = NSFont(descriptor: roundedDescriptor, size: 22) ?? systemFont
        titleLabel.textColor = NSColor.black.withAlphaComponent(0.78)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        ellipsisImageView.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        ellipsisImageView.contentTintColor = NSColor.black.withAlphaComponent(0.42)
        ellipsisImageView.imageScaling = .scaleProportionallyDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        ellipsisImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(ellipsisImageView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: ellipsisImageView.leadingAnchor, constant: -12),
            ellipsisImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ellipsisImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ellipsisImageView.widthAnchor.constraint(equalToConstant: 22),
            ellipsisImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        if let control = super.hitTest(point) as? NSControl, control.isEnabled {
            if let textField = control as? NSTextField {
                if textField.isEditable || textField.isSelectable {
                    return control
                }
            } else {
                return control
            }
        }

        return self
    }

    override func mouseDown(with event: NSEvent) {
        #if DEBUG
        print("TodoSticky DEBUG: drag mouseDown")
        #endif

        guard let window, window.isMovable else { return }

        #if DEBUG
        print("TodoSticky DEBUG: performDrag")
        #endif
        window.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
