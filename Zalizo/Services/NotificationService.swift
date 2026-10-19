import Foundation
import UserNotifications

/// Local notifications only (no push capability needed - works with a free Personal Team).
/// Permission is requested the first time a feature needs it, never at launch.
@MainActor
enum NotificationService {
    static let restTimerID = "rest-timer"

    static var center: UNUserNotificationCenter { .current() }

    /// Returns true if notifications may be shown (asks the first time).
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Fires when the rest is over, also on the lock screen.
    static func scheduleRestEnd(after seconds: TimeInterval, nextSet: String, sound: Bool) {
        cancelRestEnd()
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Відпочинок завершено")
        content.body = nextSet
        content.sound = sound ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: restTimerID, content: content, trigger: trigger))
    }

    static func cancelRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [restTimerID])
        center.removeDeliveredNotifications(withIdentifiers: [restTimerID])
    }
}
