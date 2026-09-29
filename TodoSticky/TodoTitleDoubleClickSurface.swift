import AppKit
import SwiftUI

struct TodoTitleDoubleClickSurface: NSViewRepresentable {
    let todoID: UUID
    let onDoubleClick: (UUID) -> Void

    func makeNSView(context: Context) -> NSView {
        ClickSurfaceView(todoID: todoID, onDoubleClick: onDoubleClick)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let clickSurface = nsView as? ClickSurfaceView else { return }
        clickSurface.todoID = todoID
        clickSurface.onDoubleClick = onDoubleClick
    }

    private final class ClickSurfaceView: NSView {
        var todoID: UUID
        var onDoubleClick: (UUID) -> Void

        init(todoID: UUID, onDoubleClick: @escaping (UUID) -> Void) {
            self.todoID = todoID
            self.onDoubleClick = onDoubleClick
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            #if DEBUG
            log("title hit todoID=\(todoID) clickCount=\(event.clickCount)")
            #endif
            guard event.clickCount == 2 else { return }
            #if DEBUG
            log("native double-click callback todoID=\(todoID)")
            #endif
            onDoubleClick(todoID)
        }

        #if DEBUG
        private func log(_ message: String) {
            FileHandle.standardError.write(Data("TodoSticky DEBUG: edit \(message)\n".utf8))
        }
        #endif
    }
}
