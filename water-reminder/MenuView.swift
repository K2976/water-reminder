import SwiftUI
import ServiceManagement

/// The dropdown shown when clicking the menu bar icon.
/// With `.menuBarExtraStyle(.menu)` each view here becomes a native menu item.
struct MenuView: View {
    @ObservedObject var timer: ReminderTimer

    var body: some View {
        // Plain Text becomes a greyed-out, non-clickable status line.
        Text(statusText)

        Button("I drank water") { timer.restart() }
            .disabled(timer.isPaused)

        Divider()

        // A Picker inside a menu shows as a submenu with a checkmark on the current value.
        Picker("Interval", selection: $timer.intervalMinutes) {
            ForEach(ReminderTimer.intervalChoices, id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }

        // Toggles show as menu items with a checkmark when on.
        Toggle("Pause reminders", isOn: Binding(
            get: { timer.isManuallyPaused },
            set: { shouldPause in
                if shouldPause { timer.pause(.manual) } else { timer.resume(.manual) }
            }
        ))

        Toggle("Launch at login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { setLaunchAtLogin($0) }
        ))

        Divider()

        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusText: String {
        guard let minutes = timer.minutesUntilNextReminder else { return "Paused" }
        return minutes == 1 ? "Next reminder in 1 min" : "Next reminder in \(minutes) min"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Usually means the app isn't in a stable location like /Applications.
            print("Launch at login change failed: \(error)")
        }
    }
}
