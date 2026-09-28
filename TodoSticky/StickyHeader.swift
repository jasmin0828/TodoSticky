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
            if #available(macOS 27.0, *) {
                item.preferredImageVisibility = .visible
            }
            item.state = color == selectedColor ? .on : .off
            menu.addItem(item)
        }

        #if DEBUG
        if !Self.didLogColorMenuDiagnostics {
            logColorMenuDiagnostics(menu)
            Self.didLogColorMenuDiagnostics = true
        }
        #endif

        return menu
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
