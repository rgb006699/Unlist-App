import UserNotifications

/// Shows reminders while the app is open and opens the broker when one is tapped.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    // Set once at launch, before any notification can arrive.
    nonisolated(unsafe) var onOpenBroker: (@MainActor (String) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let brokerId = response.notification.request.content.userInfo["brokerId"] as? String else { return }
        let open = onOpenBroker
        await MainActor.run { open?(brokerId) }
    }
}
