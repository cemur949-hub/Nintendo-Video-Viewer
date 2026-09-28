import Foundation
import UserNotifications

/// Local notifications only. The app has no push (`aps-environment`) entitlement.
enum NotificationService {
    private static let refreshReminderIDs = ["refresh-reminder-1d", "refresh-reminder-3h"]

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Reminds you to refresh in SideStore before the signing profile expires
    /// (every 7 days on a free Apple ID). Each call replaces the previous reminders.
    static func scheduleRefreshReminders(expiry: Date) {
        cancelRefreshReminders()

        let reminders: [(id: String, fireDate: Date, when: String)] = [
            (refreshReminderIDs[0], expiry.addingTimeInterval(-24 * 60 * 60), "in about a day"),
            (refreshReminderIDs[1], expiry.addingTimeInterval(-3 * 60 * 60), "in about 3 hours"),
        ]

        for reminder in reminders where reminder.fireDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Refresh in SideStore"
            content.body = "This app's signature expires \(reminder.when). Open SideStore and tap Refresh All so it keeps opening."
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    static func cancelRefreshReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: refreshReminderIDs)
    }
}
