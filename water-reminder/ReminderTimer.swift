import Combine   // provides ObservableObject and @Published
import Foundation

/// Owns the countdown to the next reminder, and knows whether reminders are paused.
///
/// Instead of counting seconds down, it stores the *date* of the next reminder.
/// Remaining time is always "next reminder date minus now", so it can never drift.
final class ReminderTimer: NSObject, ObservableObject {

    /// Why reminders are paused. Several can be true at once (e.g. idle AND locked),
    /// and the countdown only resumes once all of them are gone.
    enum PauseReason {
        case manual        // the "Pause reminders" toggle in the menu
        case screenLocked
        case asleep
        case idle          // no keyboard/mouse input for a while
    }

    static let intervalChoices = [30, 45, 60, 90]
    private static let defaultIntervalMinutes = 5
    private static let snoozeMinutes = 10
    private static let intervalDefaultsKey = "intervalMinutes"

    /// When the next reminder fires. `nil` while paused.
    @Published private(set) var nextReminderDate: Date?

    /// The current time, refreshed every second so the menu text stays live.
    @Published private(set) var now = Date()

    @Published private(set) var pauseReasons: Set<PauseReason> = []

    /// Minutes between reminders, saved in UserDefaults. Changing it restarts the countdown.
    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Self.intervalDefaultsKey)
            restart()
        }
    }

    /// Called when a reminder is due. The app wires this to "post a notification",
    /// so this class doesn't need to know anything about notifications.
    var onReminderDue: (() -> Void)?

    private var ticker: Timer?

    var isPaused: Bool { !pauseReasons.isEmpty }
    var isManuallyPaused: Bool { pauseReasons.contains(.manual) }

    /// Whole minutes left until the next reminder, rounded up (so 44m10s shows as 45).
    var minutesUntilNextReminder: Int? {
        guard let nextReminderDate else { return nil }
        let secondsLeft = max(0, nextReminderDate.timeIntervalSince(now))
        return Int((secondsLeft / 60).rounded(.up))
    }

    override init() {
        // integer(forKey:) returns 0 when nothing has been saved yet.
        let saved = UserDefaults.standard.integer(forKey: Self.intervalDefaultsKey)
        intervalMinutes = Self.intervalChoices.contains(saved) ? saved : Self.defaultIntervalMinutes
        super.init()
    }

    /// Starts ticking once a second and begins the first countdown.
    func start() {
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        // `.common` mode keeps the timer firing while the menu is open
        // (the default mode is suspended during menu tracking).
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        restart()
    }

    /// Starts a full countdown from now. Used by "I drank water" and the "Drank" action.
    func restart() {
        guard !isPaused else { return }
        nextReminderDate = Date().addingTimeInterval(TimeInterval(intervalMinutes * 60))
    }

    /// Sets the next reminder to 10 minutes from now. Used by the "Snooze" action.
    func snooze() {
        guard !isPaused else { return }
        nextReminderDate = Date().addingTimeInterval(TimeInterval(Self.snoozeMinutes * 60))
    }

    func pause(_ reason: PauseReason) {
        pauseReasons.insert(reason)
        nextReminderDate = nil
    }

    /// Removes one pause reason. If it was the last one, a fresh countdown starts.
    /// Reminders missed while paused are simply dropped, never fired as a backlog.
    func resume(_ reason: PauseReason) {
        // Already not paused for this reason (e.g. the idle check runs repeatedly): nothing to do.
        guard pauseReasons.contains(reason) else { return }
        pauseReasons.remove(reason)
        restart()
    }

    @objc private func tick() {
        now = Date()
        guard let nextReminderDate, now >= nextReminderDate else { return }
        onReminderDue?()
        restart()
    }
}
