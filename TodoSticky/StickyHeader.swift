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
final class StickyHeaderView: NSView, NSMenuDelegate {
    private let titleLabel = NSTextField(labelWithString: String(localized: "todo.header.title"))
    private let colorButton = StickyColorButton()
    private var onSelectColor: ((StickyColor) -> Void)?
    private var selectedColor: StickyColor?
    private var isPointerInside = false
    private var isColorMenuOpen = false
    private var areHeaderControlsVisible = false
    private var isKeyboardFocused = false
    private var isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
    private var accessibilityOptionsObserver: NSObjectProtocol?
    private weak var hoverTrackingHost: NSView?
    private var windowHoverTrackingArea: NSTrackingArea?
    #if DEBUG
    private static var didLogColorMenuDiagnostics = false
    private var hoverDiagnosticCount = 0
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

        if colorButton.menu == nil {
            self.selectedColor = selectedColor
            colorButton.menu = makeColorMenu(selectedColor: selectedColor)
        } else if self.selectedColor != selectedColor {
            self.selectedColor = selectedColor
            if !isColorMenuOpen {
                updateColorMenuSelection(for: selectedColor)
            }
        }

        updateHeaderControlVisibility(reason: "swiftui-update")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeAccessibilityOptionsObserver()
            removeWindowHoverTracking()
            setPointerInside(false, reason: "detached-from-window")
        } else {
            observeAccessibilityOptions()
            installWindowHoverTracking()
        }
        updateHeaderControlVisibility(reason: "view-did-move-to-window")
    }

    private func configureHeader() {
        let systemFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) ?? systemFont.fontDescriptor
        titleLabel.font = NSFont(descriptor: roundedDescriptor, size: 22) ?? systemFont
        titleLabel.textColor = NSColor.black.withAlphaComponent(0.78)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        colorButton.image = NSImage(
            systemSymbolName: "ellipsis",
            accessibilityDescription: String(localized: "color.menu.accessibility")
        )?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        colorButton.contentTintColor = NSColor.black.withAlphaComponent(0.48)
        colorButton.isHidden = true
        colorButton.alphaValue = 1
        colorButton.isEnabled = true
        colorButton.isBordered = false
        colorButton.focusRingType = .none
        colorButton.target = self
        colorButton.action = #selector(showColorMenu)
        colorButton.setAccessibilityLabel(String(localized: "color.menu.accessibility"))
        colorButton.toolTip = String(localized: "color.menu.accessibility")
        colorButton.onKeyboardFocusChanged = { [weak self] isFocused in
            self?.isKeyboardFocused = isFocused
            self?.updateHeaderControlVisibility(reason: "keyboard-focus-\(isFocused)")
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
                self.updateHeaderControlVisibility(reason: "voiceover-state-changed")
            }
        }
    }

    private func installWindowHoverTracking() {
        removeWindowHoverTracking()

        guard let window, let contentView = window.contentView else {
            #if DEBUG
            logHoverDiagnostic("tracking install failed: no window contentView")
            #endif
            return
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        hoverTrackingHost = contentView
        windowHoverTrackingArea = trackingArea

        #if DEBUG
        logHoverDiagnostic(
            "tracking installed host=\(debugIdentity(contentView)) " +
                "bounds=\(NSStringFromRect(contentView.bounds)) " +
                "visibleRect=\(NSStringFromRect(contentView.visibleRect)) " +
                "options=mouseEnteredAndExited,activeAlways,inVisibleRect"
        )
        #endif

        setPointerInside(pointerIsOverWindowContent(), reason: "tracking-installed-pointer-snapshot")
    }

    private func removeWindowHoverTracking() {
        guard let windowHoverTrackingArea else { return }
        hoverTrackingHost?.removeTrackingArea(windowHoverTrackingArea)
        self.windowHoverTrackingArea = nil
        hoverTrackingHost = nil
        #if DEBUG
        logHoverDiagnostic("tracking removed")
        #endif
    }

    private func pointerIsOverWindowContent() -> Bool {
        guard let window, let contentView = window.contentView else { return false }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let contentPoint = contentView.convert(windowPoint, from: nil)
        return contentView.bounds.contains(contentPoint)
    }

    private func setPointerInside(_ isInside: Bool, reason: String) {
        let pointerBefore = isPointerInside
        let visibilityBefore = areHeaderControlsVisible
        isPointerInside = isInside
        updateHeaderControlVisibility(reason: reason)
        #if DEBUG
        logHoverDiagnostic(
            "pointer callback=\(reason) pointer=\(pointerBefore)->\(isPointerInside) " +
                "visible=\(visibilityBefore)->\(areHeaderControlsVisible) " +
                "liveControls=\(areHeaderControlsLive)"
        )
        #endif
    }

    override func mouseEntered(with event: NSEvent) {
        setPointerInside(true, reason: "mouseEntered")
    }

    override func mouseExited(with event: NSEvent) {
        setPointerInside(false, reason: "mouseExited")
    }

    private var areHeaderControlsLive: Bool {
        guard let window else { return false }
        let trafficLightButtons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]
        return colorButton.window === window
            && colorButton.superview === self
            && trafficLightButtons.allSatisfy { $0?.window === window }
    }

    #if DEBUG
    private func logHoverDiagnostic(_ message: String) {
        guard hoverDiagnosticCount < 80 else { return }
        hoverDiagnosticCount += 1
        let diagnostic =
            "TodoSticky DEBUG: hover \(message) " +
                "window=\(window?.windowNumber ?? -1) " +
                "header=\(debugIdentity(self)) colorButton=\(debugIdentity(colorButton)) " +
                "controlsLive=\(areHeaderControlsLive) trafficLights=[\(nativeTrafficLightStateDescription)] " +
                "menuOpen=\(isColorMenuOpen) keyboardFocused=\(isKeyboardFocused) " +
                "voiceOver=\(isVoiceOverEnabled) controlsVisible=\(areHeaderControlsVisible) " +
                "colorHidden=\(colorButton.isHidden) " +
                "colorAlpha=\(colorButton.alphaValue)"
        FileHandle.standardError.write(Data("\(diagnostic)\n".utf8))
    }

    private var nativeTrafficLightStateDescription: String {
        guard let window else { return "window=nil" }
        let controls: [(String, NSWindow.ButtonType)] = [
            ("close", .closeButton),
            ("miniaturize", .miniaturizeButton),
            ("zoom", .zoomButton)
        ]
        return controls.map { name, type in
            guard let button = window.standardWindowButton(type) else { return "\(name)=missing" }
            return "\(name)=hidden:\(button.isHidden),window:\(button.window?.windowNumber ?? -1)"
        }.joined(separator: ",")
    }

    private func debugIdentity(_ object: AnyObject) -> String {
        String(describing: Unmanaged.passUnretained(object).toOpaque())
    }
    #endif

    private func removeAccessibilityOptionsObserver() {
        guard let accessibilityOptionsObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(accessibilityOptionsObserver)
        self.accessibilityOptionsObserver = nil
    }

    private func makeColorMenu(selectedColor: StickyColor) -> NSMenu {
        let menu = NSMenu(title: String(localized: "color.menu.title"))
        let heading = NSMenuItem(title: String(localized: "color.menu.heading"), action: nil, keyEquivalent: "")
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

    private func updateHeaderControlVisibility(reason: String) {
        let shouldBeVisible = isPointerInside
            || isColorMenuOpen
            || isKeyboardFocused
            || isVoiceOverEnabled
        let visibilityBefore = areHeaderControlsVisible
        let colorHiddenBefore = colorButton.isHidden
        areHeaderControlsVisible = shouldBeVisible
        setNativeTrafficLightsHidden(!shouldBeVisible)
        if shouldBeVisible {
            colorButton.isHidden = false
            colorButton.alphaValue = 1
            colorButton.isEnabled = true
        } else {
            colorButton.isHidden = true
        }

        if visibilityBefore != shouldBeVisible
            || colorHiddenBefore != !shouldBeVisible {
            needsLayout = true
            layoutSubtreeIfNeeded()
            colorButton.needsDisplay = true
            needsDisplay = true
        }

        #if DEBUG
        if reason == "mouseEntered" || reason == "mouseExited" {
            logColorButtonGeometry(event: reason, hiddenBefore: colorHiddenBefore)
        }
        #endif

        if visibilityBefore != shouldBeVisible {
            #if DEBUG
            logHoverDiagnostic(
                "visibility updated reason=\(reason) visible=\(visibilityBefore)->\(shouldBeVisible) " +
                    "colorHidden=\(colorHiddenBefore)->\(colorButton.isHidden) " +
                    "trafficLights=[\(nativeTrafficLightStateDescription)] " +
                    "liveControls=\(areHeaderControlsLive)"
            )
            #endif
        }
    }

    #if DEBUG
    private func logColorButtonGeometry(event: String, hiddenBefore: Bool) {
        let buttonFrame = colorButton.convert(colorButton.bounds, to: self)
        let visibleHeaderBounds = visibleRect.intersection(bounds)
        let visibleIntersection = buttonFrame.intersection(visibleHeaderBounds)
        let buttonWindowNumber = colorButton.window?.windowNumber ?? -1
        let headerWindowNumber = window?.windowNumber ?? -1
        let tintDescription = colorButton.contentTintColor.map { String(describing: $0) } ?? "nil"
        let superviewDescription = colorButton.superview.map {
            "\(type(of: $0))@\(debugIdentity($0))"
        } ?? "nil"

        let diagnostic =
            "TodoSticky DEBUG: hover geometry event=\(event) " +
                "header=\(debugIdentity(self)) colorButton=\(debugIdentity(colorButton)) " +
                "colorHidden=\(hiddenBefore)->\(colorButton.isHidden) " +
                "colorFrame=\(NSStringFromRect(buttonFrame)) " +
                "colorBounds=\(NSStringFromRect(colorButton.bounds)) " +
                "colorIntersection=\(NSStringFromRect(visibleIntersection)) " +
                "colorEnabled=\(colorButton.isEnabled) colorAlpha=\(colorButton.alphaValue) " +
                "headerBounds=\(NSStringFromRect(bounds)) " +
                "visibleHeaderBounds=\(NSStringFromRect(visibleHeaderBounds)) " +
                "superview=\(superviewDescription) " +
                "colorWindow=\(buttonWindowNumber) headerWindow=\(headerWindowNumber) " +
                "sameWindow=\(buttonWindowNumber >= 0 && buttonWindowNumber == headerWindowNumber) " +
                "trafficLights=[\(nativeTrafficLightStateDescription)] " +
                "tint=\(tintDescription)"
        FileHandle.standardError.write(Data("\(diagnostic)\n".utf8))
    }
    #endif

    private func setNativeTrafficLightsHidden(_ isHidden: Bool) {
        guard let window else { return }
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = isHidden
        }
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
        #if DEBUG
        logHoverDiagnostic("menuWillOpen")
        #endif
        updateHeaderControlVisibility(reason: "menu-will-open")
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === colorButton.menu else { return }
        isColorMenuOpen = false
        #if DEBUG
        logHoverDiagnostic("menuDidClose")
        #endif
        setPointerInside(pointerIsOverWindowContent(), reason: "menu-did-close-pointer-snapshot")

        // Wait until AppKit finishes menu tracking before updating menu item state.
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let selectedColor = self.selectedColor {
                self.updateColorMenuSelection(for: selectedColor)
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        if let control = super.hitTest(point) as? NSControl, control.isEnabled {
            if control === colorButton, colorButton.isHidden {
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
