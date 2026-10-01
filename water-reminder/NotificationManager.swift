import UserNotifications

/// Asks for notification permission, posts the reminder, and handles the
/// "Drank" / "Snooze 10 min" buttons on it.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    private static let categoryID = "WATER_REMINDER"
    private static let drankActionID = "DRANK"
    private static let snoozeActionID = "SNOOZE"

    /// Set by the app: what to do when the user presses each button.
    var onDrank: (() -> Void)?
    var onSnooze: (() -> Void)?

    private let center = UNUserNotificationCenter.current()

    func setUp() {
        center.delegate = self

        // A "category" is a named set of buttons. Each notification we post
        // refers to it by ID, so macOS knows which buttons to show.
        let drank = UNNotificationAction(identifier: Self.drankActionID, title: "Drank")
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID, title: "Snooze 10 min")
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [drank, snooze],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        // macOS shows the permission prompt only the first time; later calls return immediately.
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Drink Water"
        content.body = "Time for a glass of water."
        content.sound = .default
        content.categoryIdentifier = Self.categoryID

        // trigger: nil means "deliver right now". The app's own timer decides when;
        // we never schedule repeating system triggers.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate
    // macOS calls these from a background thread, hence `nonisolated`.
    // We read what we need, then `await` hops back to the main thread for handleAction.

    /// Called when the user clicks the notification or one of its buttons.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionID = response.actionIdentifier
        await handleAction(actionID)
    }

    /// Called when a notification arrives while our app is "in front" (e.g. the menu is open).
    /// By default macOS would hide it; we ask for it to be shown normally.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func handleAction(_ actionID: String) {
        switch actionID {
        case Self.snoozeActionID:
            onSnooze?()
        case Self.drankActionID, UNNotificationDefaultActionIdentifier:
            // Clicking the notification body itself counts as "Drank".
            onDrank?()
        default:
            break
        }
    }
}
