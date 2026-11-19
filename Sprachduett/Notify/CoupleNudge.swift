import UserNotifications

enum CoupleNudge {
    static let identifier = "partner-nudge"

    static func schedule(_ fire: Bool) {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard fire else { return }
        center.requestAuthorization(options: [.alert, .sound]) { allowed, _ in
            guard allowed else { return }
            let content = UNMutableNotificationContent()
            content.title = "Sprachduett"
            content.body = CoupleReminder.body
            var when = DateComponents()
            when.hour = CoupleReminder.hour
            when.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }
}
