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
    private let framePreferences = WindowFramePreferences()
    private var frameSaveTask: Task<Void, Never>?
    private var stickyWindow: NSWindow?
    private var todoStore: TodoStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = TodoStore.applicationStore()
        todoStore = store

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
        window.minSize = NSSize(width: 320, height: 180)
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

        let hostingView = NSHostingView(rootView: StickyView(store: store))
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.setFrame(restoredFrame(for: window), display: true)

        stickyWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        scheduleFrameSave()
    }

    func windowDidResize(_ notification: Notification) {
        #if DEBUG
        if let window = notification.object as? NSWindow {
            print("TodoSticky DEBUG: window resized \(Int(window.frame.width))x\(Int(window.frame.height))")
        }
        #endif
        scheduleFrameSave()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowWillClose(_ notification: Notification) {
        frameSaveTask?.cancel()
        saveWindowFrame()
    }

    private func restoredFrame(for window: NSWindow) -> NSRect {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        let fallback = NSScreen.main?.visibleFrame
            ?? visibleFrames.first
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let restored = StickyWindowFrame.restoring(
            saved: framePreferences.load(),
            visibleScreenFrames: visibleFrames,
            fallbackScreenFrame: fallback,
            defaultSize: NSSize(width: 360, height: 460),
            minimumSize: window.minSize
        )
        return restored.rect
    }

    private func scheduleFrameSave() {
        frameSaveTask?.cancel()
        frameSaveTask = Task { @MainActor [weak self, weak window = stickyWindow] in
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }
            guard let self, let window else { return }
            self.framePreferences.save(StickyWindowFrame(rect: window.frame))
        }
    }

    private func saveWindowFrame() {
        guard let stickyWindow else { return }
        framePreferences.save(StickyWindowFrame(rect: stickyWindow.frame))
    }
}
