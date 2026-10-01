import AppKit
import CoreFoundation
import CoreGraphics
import SwiftUI

final class TodoStateInvalidationObserver {
    private let name: CFNotificationName
    private let onChange: @Sendable () -> Void

    init(name: String = TodoStateInvalidation.name, onChange: @escaping @Sendable () -> Void) {
        self.name = CFNotificationName(name as CFString)
        self.onChange = onChange

        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let listener = Unmanaged<TodoStateInvalidationObserver>
                    .fromOpaque(observer).takeUnretainedValue()
                listener.onChange()
            },
            self.name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
        CFNotificationCenterRemoveObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            name,
            nil
        )
    }
}

@main
struct TodoStickyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView(todoStore: appDelegate.todoStore)
                .environment(appDelegate.languageController)
                .environment(\.locale, appDelegate.languageController.locale)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let languageController = AppLanguageController()
    private let framePreferences = WindowFramePreferences()
    private var frameSaveTask: Task<Void, Never>?
    private var stickyWindow: NSWindow?
    private var isClosingStickyWindow = false
    lazy var todoStore = TodoStore.applicationStore()
    private var stateInvalidationObserver: TodoStateInvalidationObserver?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = todoStore
        stateInvalidationObserver = TodoStateInvalidationObserver { [weak store] in
            Task { @MainActor in
                store?.reloadFromDisk()
            }
        }
        // Close the gap between the initial load and observer registration.
        store.reloadFromDisk()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = String(localized: "app.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 320, height: 180)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        #if DEBUG
        print("TodoSticky DEBUG: native window shadow = \(window.hasShadow)")
        #endif

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
        // Keep the native green zoom control out of full-screen Spaces.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        let hostingView = NSHostingView(
            rootView: StickyView(store: store)
                .environment(languageController)
                .environment(\.locale, languageController.locale)
        )
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.setFrame(restoredFrame(for: window), display: true)

        stickyWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        todoStore.reloadFromDisk()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        frameSaveTask?.cancel()
        frameSaveTask = nil

        // Save while the app and window are still alive. A last-window close
        // has already saved its frame in windowWillClose(_:) and is no longer visible.
        if !isClosingStickyWindow, let window = stickyWindow {
            framePreferences.save(StickyWindowFrame(rect: window.frame))
        }
        return .terminateNow
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
        isClosingStickyWindow = true
        frameSaveTask?.cancel()
        frameSaveTask = nil
        guard let window = notification.object as? NSWindow else { return }
        framePreferences.save(StickyWindowFrame(rect: window.frame))
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
