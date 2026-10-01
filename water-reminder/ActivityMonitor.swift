import AppKit
import CoreGraphics

/// Watches for screen lock, sleep, and idleness, and pauses/resumes the timer accordingly.
final class ActivityMonitor: NSObject {

    /// No keyboard/mouse input for this long counts as "away".
    private static let idleThresholdSeconds: TimeInterval = 5 * 60
    private static let idleCheckIntervalSeconds: TimeInterval = 10

    private let timer: ReminderTimer
    private var idleCheckTimer: Timer?

    init(timer: ReminderTimer) {
        self.timer = timer
        super.init()
    }

    func start() {
        // Screen lock/unlock is only announced on the *distributed* notification center
        // (system-wide notifications shared between apps).
        let distributedCenter = DistributedNotificationCenter.default()
        distributedCenter.addObserver(self, selector: #selector(screenLocked),
                                      name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributedCenter.addObserver(self, selector: #selector(screenUnlocked),
                                      name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        // Sleep/wake is posted on NSWorkspace's own notification center, not the default one.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(willSleep),
                                    name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(didWake),
                                    name: NSWorkspace.didWakeNotification, object: nil)

        // macOS has no "user went idle" notification, so we check every few seconds.
        idleCheckTimer = Timer.scheduledTimer(timeInterval: Self.idleCheckIntervalSeconds, target: self,
                                              selector: #selector(checkIdle), userInfo: nil, repeats: true)
    }

    @objc private func screenLocked() { timer.pause(.screenLocked) }
    @objc private func screenUnlocked() { timer.resume(.screenLocked) }
    @objc private func willSleep() { timer.pause(.asleep) }
    @objc private func didWake() { timer.resume(.asleep) }

    @objc private func checkIdle() {
        // Seconds since the last keyboard/mouse/trackpad event of any kind.
        // Apple's C constant for "any input event" is kCGAnyInputEventType (~0, all bits set);
        // Swift doesn't expose it by name, so we build it from its raw value.
        let anyInputEvent = CGEventType(rawValue: ~0)!
        let secondsIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEvent)

        if secondsIdle >= Self.idleThresholdSeconds {
            timer.pause(.idle)
        } else {
            timer.resume(.idle)
        }
    }
}
