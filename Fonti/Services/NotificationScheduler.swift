// Fonti/Services/NotificationScheduler.swift
//
// Thin wrapper around UNUserNotificationCenter for the two things Fonti
// needs today: request-permission (deferred until after a success moment)
// and a single "come back and play with fonts" reminder that always sits
// N days past the user's most recent capture.

import Foundation
import UserNotifications

enum NotificationScheduler {
    static let engagementRequestId = "fonti.notification.engagement"
    static let defaultEngagementDays: Int = 5

    /// Returns true when the app has permission to display notifications.
    /// Prompts the user only if they've never been asked.
    @discardableResult
    static func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Cancels any pending engagement reminder and schedules a fresh one N
    /// days out. Called after every capture so the reminder always trails
    /// the user's most recent activity.
    static func rescheduleEngagementReminder(days: Int = defaultEngagementDays) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [engagementRequestId])

        let content = UNMutableNotificationContent()
        content.title = "Your fonts miss you"
        content.body = "Try a new font in Fonti today."
        content.sound = .default

        let seconds = TimeInterval(days) * 24 * 3600
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: engagementRequestId,
            content: content,
            trigger: trigger
        )
        // UNUserNotificationCenter silently drops the request if the user
        // hasn't authorized notifications, so it's safe to call every time.
        center.add(request) { _ in }
    }

    static func cancelEngagementReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [engagementRequestId])
    }
}
