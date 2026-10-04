import UserNotifications

/// Whether Lin has turned DayShift's alerts off, for the Today banner (6.3).
protocol AlertsStatusChecking {
    func alertsAreOff() async -> Bool
}

/// Reads the notification permission. Alerts are only "off" once Lin has
/// declined; before she is asked (Step 9) there is no banner.
struct NotificationSettingsAlertsStatus: AlertsStatusChecking {
    func alertsAreOff() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
