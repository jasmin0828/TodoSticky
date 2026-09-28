import AppKit

@MainActor
final class StickyColorButton: NSButton {
    var onKeyboardFocusChanged: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        onKeyboardFocusChanged?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        onKeyboardFocusChanged?(false)
        return true
    }
}
