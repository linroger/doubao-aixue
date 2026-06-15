//
//  NotificationService.swift
//  豆包爱学
//
//  Thin wrapper over UserNotifications for review reminders and check-ins.
//

import Foundation
import UserNotifications

public struct NotificationService: Sendable {
    public init() {}

    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedule a daily reminder at the given time.
    public func scheduleDaily(id: String, title: String, body: String, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
