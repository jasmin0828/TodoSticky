import AppKit
import SwiftUI

struct StickyHeader: NSViewRepresentable {
    let selectedColor: StickyColor
    let shouldRevealColorControl: Bool
    let onSelectColor: (StickyColor) -> Void
    let onMenuVisibilityChanged: (Bool) -> Void

    func makeNSView(context: Context) -> StickyHeaderView {
        StickyHeaderView()
    }

    func updateNSView(_ nsView: StickyHeaderView, context: Context) {
        nsView.update(
            selectedColor: selectedColor,
            shouldRevealColorControl: shouldRevealColorControl,
            onSelectColor: onSelectColor,
            onMenuVisibilityChanged: onMenuVisibilityChanged
        )
    }
}

@MainActor
final class StickyHeaderView: NSView, NSMenuDelegate {
    private let titleLabel = NSTextField(labelWithString: "待办")
    private let colorButton = StickyColorButton()
    private var onSelectColor: ((StickyColor) -> Void)?
    private var onMenuVisibilityChanged: ((Bool) -> Void)?
    private var selectedColor: StickyColor?
    private var shouldRevealColorControl = false
    private var isColorMenuOpen = false
    private var isColorButtonVisible = false
    private var isKeyboardFocused = false
    private var isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
    private var accessibilityOptionsObserver: NSObjectProtocol?
    #if DEBUG
    private static var didLogColorMenuDiagnostics = false
    #endif

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHeader()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHeader()
    }

    func update(
        selectedColor: StickyColor,
        shouldRevealColorControl: Bool,
        onSelectColor: @escaping (StickyColor) -> Void,
        onMenuVisibilityChanged: @escaping (Bool) -> Void
    ) {
        self.onSelectColor = onSelectColor
        self.onMenuVisibilityChanged = onMenuVisibilityChanged
        self.shouldRevealColorControl = shouldRevealColorControl

        if colorButton.menu == nil {
            self.selectedColor = selectedColor
            colorButton.menu = makeColorMenu(selectedColor: selectedColor)
        } else if self.selectedColor != selectedColor {
            self.selectedColor = selectedColor
            if !isColorMenuOpen {
                updateColorMenuSelection(for: selectedColor)
            }
        }

        updateColorButtonVisibility()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeAccessibilityOptionsObserver()
        } else {
            observeAccessibilityOptions()
        }
        updateColorButtonVisibility()
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
        // Keep the native button accessible; hide only its template glyph while idle.
        colorButton.contentTintColor = NSColor.black.withAlphaComponent(0)
        colorButton.isBordered = false
        colorButton.focusRingType = .none
        colorButton.target = self
        colorButton.action = #selector(showColorMenu)
        colorButton.setAccessibilityLabel("便签颜色")
        colorButton.toolTip = "便签颜色"
        colorButton.onKeyboardFocusChanged = { [weak self] isFocused in
            self?.isKeyboardFocused = isFocused
            self?.updateColorButtonVisibility()
        }

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

    private func observeAccessibilityOptions() {
        guard accessibilityOptionsObserver == nil else { return }
        let workspace = NSWorkspace.shared
        accessibilityOptionsObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
                self.updateColorButtonVisibility()
            }
        }
    }

    private func removeAccessibilityOptionsObserver() {
        guard let accessibilityOptionsObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(accessibilityOptionsObserver)
        self.accessibilityOptionsObserver = nil
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
            if #available(macOS 27.0, *) {
                item.preferredImageVisibility = .visible
            }
            item.state = color == selectedColor ? .on : .off
            menu.addItem(item)
        }
        menu.delegate = self

        #if DEBUG
        if !Self.didLogColorMenuDiagnostics {
            logColorMenuDiagnostics(menu)
            Self.didLogColorMenuDiagnostics = true
        }
        #endif

        return menu
    }

    private func updateColorMenuSelection(for selectedColor: StickyColor) {
        for item in colorButton.menu?.items ?? [] {
            guard let rawValue = item.representedObject as? String,
                  let color = StickyColor(rawValue: rawValue) else { continue }
            item.state = color == selectedColor ? .on : .off
        }
    }

    private func updateColorButtonVisibility() {
        let shouldBeVisible = shouldRevealColorControl
            || isColorMenuOpen
            || isKeyboardFocused
            || isVoiceOverEnabled
        guard isColorButtonVisible != shouldBeVisible else { return }
        isColorButtonVisible = shouldBeVisible
        colorButton.contentTintColor = NSColor.black.withAlphaComponent(shouldBeVisible ? 0.48 : 0)
    }

    private func makeColorSwatch(for color: StickyColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let pixelSize = 24
        let image: NSImage

        if let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
            let circle = CGRect(x: 2.5, y: 2.5, width: 19, height: 19)
            context.setFillColor(NSColor(color.color).cgColor)
            context.fillEllipse(in: circle)
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.18).cgColor)
            context.setLineWidth(1)
            context.strokeEllipse(in: circle)

            if let cgImage = context.makeImage() {
                image = NSImage(cgImage: cgImage, size: size)
            } else {
                image = NSImage(size: size)
            }
        } else {
            image = NSImage(size: size)
        }

        image.isTemplate = false
        return image
    }

    #if DEBUG
    private func logColorMenuDiagnostics(_ menu: NSMenu) {
        let colorItems = menu.items.filter { $0.representedObject as? String != nil }
        print("TodoSticky DEBUG: color menu item count = \(colorItems.count)")

        for item in colorItems {
            let image = item.image
            let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            let bitmap = cgImage.map(NSBitmapImageRep.init(cgImage:))
            let centerColor = bitmap?.colorAt(x: 12, y: 12)
            let cornerColor = bitmap?.colorAt(x: 0, y: 0)
            let imageSize = image.map { "\(Int($0.size.width))x\(Int($0.size.height))pt" } ?? "missing"
            let representationTypes = image?.representations
                .map { String(describing: type(of: $0)) }
                .joined(separator: ",") ?? "none"
            let templateState = image.map { String($0.isTemplate) } ?? "missing"
            let selectedState = item.state == .on ? "on" : "off"
            let imageVisibility: String
            if #available(macOS 27.0, *) {
                imageVisibility = String(describing: item.preferredImageVisibility)
            } else {
                imageVisibility = "unavailable"
            }

            print(
                "TodoSticky DEBUG: color item \(item.title) state=\(selectedState) " +
                    "image=\(imageSize) template=\(templateState) visibility=\(imageVisibility) " +
                    "reps=\(representationTypes) pixels=\(bitmap?.pixelsWide ?? 0)x\(bitmap?.pixelsHigh ?? 0) " +
                    "centerRGBA=\(rgbaDescription(centerColor)) cornerRGBA=\(rgbaDescription(cornerColor))"
            )
        }
    }

    private func rgbaDescription(_ color: NSColor?) -> String {
        guard let color = color?.usingColorSpace(.deviceRGB) else { return "unavailable" }
        return "\(Int(color.redComponent * 255)),\(Int(color.greenComponent * 255))," +
            "\(Int(color.blueComponent * 255)),\(Int(color.alphaComponent * 255))"
    }
    #endif

    @objc private func showColorMenu() {
        colorButton.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: colorButton.bounds.minY), in: colorButton)
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let color = StickyColor(rawValue: rawValue) else { return }
        onSelectColor?(color)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === colorButton.menu else { return }
        isColorMenuOpen = true
        onMenuVisibilityChanged?(true)
        updateColorButtonVisibility()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === colorButton.menu else { return }
        isColorMenuOpen = false

        // Wait until AppKit finishes menu tracking before updating menu item state.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onMenuVisibilityChanged?(false)
            if let selectedColor = self.selectedColor {
                self.updateColorMenuSelection(for: selectedColor)
            }
            self.updateColorButtonVisibility()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        if let control = super.hitTest(point) as? NSControl, control.isEnabled {
            if control === colorButton, !isColorButtonVisible {
                return self
            }

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
