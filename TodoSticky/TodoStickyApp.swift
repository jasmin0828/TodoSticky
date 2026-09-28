import AppKit
import CoreGraphics
import SwiftUI

@main
struct TodoStickyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var stickyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 460),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Todo Sticky"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 320, height: 400)
        window.isOpaque = false
        window.backgroundColor = .clear

        // The SDK's desktop level places the sticky above the desktop but below
        // ordinary application windows. It is not an always-on-top level.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        window.contentView = NSHostingView(rootView: StickyView())
        window.setFrame(initialFrame(for: window), display: true)

        stickyWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func initialFrame(for window: NSWindow) -> NSRect {
        let frameSize = window.frame.size
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visibleFrame.maxX - frameSize.width - 32,
            y: visibleFrame.maxY - frameSize.height - 32
        )
        return NSRect(origin: origin, size: frameSize)
    }
}
