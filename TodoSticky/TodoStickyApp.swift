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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
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
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 320, height: 400)
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear

        let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        let selectedLevel = desktopIconLevel + 1
        #if DEBUG
        let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
        let normalLevel = Int(CGWindowLevelForKey(.normalWindow))
        print("TodoSticky DEBUG: desktop level = \(desktopLevel)")
        print("TodoSticky DEBUG: desktop icon level = \(desktopIconLevel)")
        print("TodoSticky DEBUG: normal level = \(normalLevel)")
        print("TodoSticky DEBUG: selected level = \(selectedLevel)")
        #endif
        window.level = NSWindow.Level(rawValue: selectedLevel)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: StickyView())
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.setFrame(initialFrame(for: window), display: true)

        stickyWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowDidResize(_ notification: Notification) {
        #if DEBUG
        guard let window = notification.object as? NSWindow else { return }
        print("TodoSticky DEBUG: window resized \(Int(window.frame.width))x\(Int(window.frame.height))")
        #endif
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
