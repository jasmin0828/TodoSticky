import AppKit
import SwiftUI

struct StickyHeader: NSViewRepresentable {
    let localeIdentifier: String

    func makeNSView(context: Context) -> StickyHeaderView {
        StickyHeaderView()
    }

    func updateNSView(_ nsView: StickyHeaderView, context: Context) {
        nsView.update(localeIdentifier: localeIdentifier)
    }
}

@MainActor
final class StickyHeaderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private var localeIdentifier = Locale.current.identifier

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHeader()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHeader()
    }

    func update(localeIdentifier: String) {
        guard self.localeIdentifier != localeIdentifier else { return }
        self.localeIdentifier = localeIdentifier
        updateLocalizedStrings(localeIdentifier: localeIdentifier)
    }

    private func configureHeader() {
        updateLocalizedStrings(localeIdentifier: localeIdentifier)

        let systemFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) ?? systemFont.fontDescriptor
        titleLabel.font = NSFont(descriptor: roundedDescriptor, size: 22) ?? systemFont
        titleLabel.textColor = NSColor.black.withAlphaComponent(0.78)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }

    private func updateLocalizedStrings(localeIdentifier: String) {
        titleLabel.stringValue = Self.localizedTitle(localeIdentifier: localeIdentifier)
    }

    static func localizedTitle(localeIdentifier: String) -> String {
        AppLocaleResolver.localizedString(
            forKey: "todo.header.title",
            locale: Locale(identifier: localeIdentifier)
        )
    }

    override func mouseDown(with event: NSEvent) {
        guard let window, window.isMovable else { return }
        window.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
