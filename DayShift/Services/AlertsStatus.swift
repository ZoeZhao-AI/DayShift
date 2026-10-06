import UserNotifications

/// Lin's alerts permission (6.3): whether alerts are off, for the Today
/// banner, and asking for permission after the explanation sheet.
protocol AlertsStatusChecking {
    func alertsAreOff() async -> Bool
    /// True until Lin has been asked by iOS.
    func hasNotBeenAsked() async -> Bool
    /// Shows the system prompt. Returns true if Lin allowed alerts.
    func askForPermission() async -> Bool
}

/// Reads and requests the notification permission. Alerts are only "off"
/// once Lin has declined; before she is asked there is no banner.
struct NotificationSettingsAlertsStatus: AlertsStatusChecking {
    func alertsAreOff() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    func hasNotBeenAsked() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    func askForPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
