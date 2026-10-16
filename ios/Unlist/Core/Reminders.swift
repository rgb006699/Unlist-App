import Foundation
import UserNotifications

/// A recheck notification for one broker, at 9:00 local time on its recheck date.
struct Reminder: Equatable, Sendable {
    let id: String
    let brokerId: String
    let title: String
    let body: String
    let fireDate: DateComponents
}

protocol ReminderScheduler: Sendable {
    /// Asks for notification permission the first time; returns whether it's granted.
    func requestPermissionIfNeeded() async -> Bool
    /// Replaces every pending recheck reminder with `reminders`.
    func replaceAll(with reminders: [Reminder]) async
}

/// Reminders for every removed broker whose recheck time is still ahead.
/// Uses the stored status (not "due"), so opening the app on the morning of a
/// recheck day keeps that day's 9:00 reminder.
func reminders(for rows: [BrokerRow], now: Date = .now, calendar: Calendar = .current) -> [Reminder] {
    rows.compactMap { row in
        guard let record = row.record, record.status == .removed, let recheck = record.recheckAt else { return nil }
        let p = recheck.split(separator: "-").compactMap { Int($0) }
        let fire = DateComponents(year: p[0], month: p[1], day: p[2], hour: 9, minute: 0)
        guard let fireDate = calendar.date(from: fire), fireDate > now else { return nil }
        return Reminder(
            id: "recheck-\(row.broker.id)",
            brokerId: row.broker.id,
            title: "Time to recheck \(row.broker.name)",
            body: "Search again to make sure your listing hasn't come back.",
            fireDate: fire
        )
    }
}

/// Schedules reminders with the system notification center, on this iPhone only.
final class NotificationScheduler: ReminderScheduler {
    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    func replaceAll(with reminders: [Reminder]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("recheck-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = ["brokerId": reminder.brokerId]
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.fireDate, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    /// Whether the owner turned notifications off in Settings.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
