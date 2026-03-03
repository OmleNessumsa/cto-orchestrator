import AppKit
import SwiftUI

/// AppDelegate to configure macOS-specific window behavior
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable automatic window tabbing (macOS 10.12+)
        NSWindow.allowsAutomaticWindowTabbing = true

        // Configure window restoration
        NSApp.registerForRemoteNotifications()

        // Configure window appearance for dark theme
        configureWindowAppearance()
    }

    private func configureWindowAppearance() {
        // Apply dark appearance to all windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows {
                self.styleWindow(window)
            }
        }

        // Observe new windows being created
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            styleWindow(window)
        }
    }

    private func styleWindow(_ window: NSWindow) {
        // Dark background color matching rtBackgroundDark
        let darkColor = NSColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1.0)

        window.backgroundColor = darkColor
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)

        // Hide titlebar in fullscreen
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden

        // Observe fullscreen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillEnterFullScreen(_:)),
            name: NSWindow.willEnterFullScreenNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillExitFullScreen(_:)),
            name: NSWindow.willExitFullScreenNotification,
            object: window
        )
    }

    @objc private func windowWillEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // Completely hide toolbar/titlebar area in fullscreen
            window.toolbar?.isVisible = false
        }
    }

    @objc private func windowWillExitFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.toolbar?.isVisible = true
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Create a new window when dock icon is clicked and no windows are visible
        if !flag {
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
