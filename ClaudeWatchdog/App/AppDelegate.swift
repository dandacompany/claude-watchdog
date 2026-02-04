import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Initialize menu bar
        menuBarManager = MenuBarManager()
    }
}
