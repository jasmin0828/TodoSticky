import AppKit
import SwiftUI

struct StickyHeader: NSViewRepresentable {
    let selectedColor: StickyColor
    let onSelectColor: (StickyColor) -> Void

    func makeNSView(context: Context) -> StickyHeaderView {
        StickyHeaderView()
    }

    func updateNSView(_ nsView: StickyHeaderView, context: Context) {
        nsView.update(selectedColor: selectedColor, onSelectColor: onSelectColor)
    }
}

@MainActor
final class StickyHeaderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "待办")
    private let colorButton = NSButton()
    private var onSelectColor: ((StickyColor) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHeader()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHeader()
    }

    func update(selectedColor: StickyColor, onSelectColor: @escaping (StickyColor) -> Void) {
        self.onSelectColor = onSelectColor
        colorButton.menu = makeColorMenu(selectedColor: selectedColor)
    }

    private func configureHeader() {
        let systemFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) ?? systemFont.fontDescriptor
        titleLabel.font = NSFont(descriptor: roundedDescriptor, size: 22) ?? systemFont
        titleLabel.textColor = NSColor.black.withAlphaComponent(0.78)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        colorButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "便签颜色")?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        colorButton.contentTintColor = NSColor.black.withAlphaComponent(0.48)
        colorButton.isBordered = false
        colorButton.focusRingType = .none
        colorButton.target = self
        colorButton.action = #selector(showColorMenu)
        colorButton.setAccessibilityLabel("便签颜色")
        colorButton.toolTip = "便签颜色"

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(colorButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: colorButton.leadingAnchor, constant: -12),
            colorButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            colorButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorButton.widthAnchor.constraint(equalToConstant: 28),
            colorButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func makeColorMenu(selectedColor: StickyColor) -> NSMenu {
        let menu = NSMenu(title: "便签颜色")
        let heading = NSMenuItem(title: "颜色", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())

        for color in StickyColor.allCases {
            let item = NSMenuItem(
                title: color.title,
                action: #selector(selectColor(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = color.rawValue
            item.image = makeColorSwatch(for: color)
            item.state = color == selectedColor ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func makeColorSwatch(for color: StickyColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let fillColor = NSColor(color.color)
        return NSImage(size: size, flipped: false) { bounds in
            let circle = NSRect(x: bounds.midX - 5, y: bounds.midY - 5, width: 10, height: 10)
            let path = NSBezierPath(ovalIn: circle)
            path.lineWidth = 0.75

            fillColor.setFill()
            path.fill()
            NSColor.black.withAlphaComponent(0.16).setStroke()
            path.stroke()
            return true
        }
    }

    @objc private func showColorMenu() {
        colorButton.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: colorButton.bounds.minY), in: colorButton)
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let color = StickyColor(rawValue: rawValue) else { return }
        onSelectColor?(color)
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
