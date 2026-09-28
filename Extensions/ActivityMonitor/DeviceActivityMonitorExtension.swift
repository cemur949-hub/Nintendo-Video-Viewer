import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Adds and removes the scheduled shield when the daily window starts and ends.
///
/// iOS runs this extension only if it was signed with the Family Controls
/// entitlement. It reads the block list from the App Group, so it also needs
/// App Groups. The app checks for both and explains what's missing.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .schedule else { return }

        let selection = store.selection
        guard !selection.blocksNothing else { return }
        ShieldController.apply(selection, to: .schedule)
        store.isScheduleActive = true
        notify(title: "Scheduled lock started", body: "Your blocked apps are locked until the schedule ends.")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .schedule else { return }

        ShieldController.clear(.schedule)
        store.isScheduleActive = false
        notify(title: "Scheduled lock ended", body: "Apps blocked by the schedule are available again.")
    }

    /// Local notification only; the app uses no push notifications.
    private func notify(title: String, body: String) {
        guard store.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: "schedule-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
