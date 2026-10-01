import SwiftUI

@main
struct WaterReminderApp: App {
    // Lets a classic AppDelegate own our long-lived objects and run setup at launch.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar icon. SF Symbols here are drawn as monochrome "template" images,
        // so the drop matches Wi-Fi/battery in both light and dark menu bars.
        MenuBarExtra("Water Reminder", systemImage: "drop") {
            MenuView(timer: appDelegate.reminderTimer)
        }
        .menuBarExtraStyle(.menu)   // a real native menu, not a popover window
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let reminderTimer: ReminderTimer
    let notificationManager: NotificationManager
    let activityMonitor: ActivityMonitor

    override init() {
        let timer = ReminderTimer()
        reminderTimer = timer
        notificationManager = NotificationManager()
        activityMonitor = ActivityMonitor(timer: timer)
        super.init()
    }

    /// All the wiring between the pieces happens here, in one place.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Timer reaches zero -> show the notification.
        reminderTimer.onReminderDue = { [notificationManager] in
            notificationManager.postReminder()
        }

        // Notification buttons -> change the timer.
        notificationManager.onDrank = { [reminderTimer] in reminderTimer.restart() }
        notificationManager.onSnooze = { [reminderTimer] in reminderTimer.snooze() }

        notificationManager.setUp()
        activityMonitor.start()
        reminderTimer.start()
    }
}
