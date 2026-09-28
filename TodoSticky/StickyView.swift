import AppKit
import SwiftUI

struct StickyView: View {
    @Bindable var store: TodoStore
    @State private var draft = ""
    @State private var isPointerInside = false
    @State private var isColorMenuOpen = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 280

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(store.selectedColor.color)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(8)

                VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                    StickyHeader(
                        selectedColor: store.selectedColor,
                        shouldRevealColorControl: isPointerInside || isColorMenuOpen,
                        onSelectColor: { store.selectColor($0) },
                        onMenuVisibilityChanged: { isColorMenuOpen = $0 }
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

                StickyHoverTracker { isHovering in
                    isPointerInside = isHovering
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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

private struct StickyHoverTracker: NSViewRepresentable {
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> StickyHoverTrackingView {
        let view = StickyHoverTrackingView()
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: StickyHoverTrackingView, context: Context) {
        nsView.onHoverChanged = onHoverChanged
    }
}

@MainActor
private final class StickyHoverTrackingView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
