import DayShiftKit
import Foundation
import os

/// Schedules nothing until Step 9 (feature/notifications) adds the
/// UNUserNotificationCenter scheduler. Logs what it would have scheduled.
struct PlaceholderNotificationScheduler: NotificationScheduling {
    private static let logger = Logger(subsystem: "com.utsstudent.zhaoziying.DayShift", category: "Notifications")

    func scheduleLeaveReminder(_ reminder: LeaveReminder) async throws {
        Self.logger.debug("Would schedule \(NotificationIdentifier.leaveReminder(planID: reminder.planID), privacy: .public) at \(reminder.fireAt, privacy: .public)")
    }

    func schedulePlanAffectedAlert(_ alert: PlanAffectedAlert) async throws {
        Self.logger.debug("Would schedule \(NotificationIdentifier.planAffected(planID: alert.planID), privacy: .public): \(alert.reason, privacy: .public)")
    }

    func removeNotifications(forPlan planID: UUID) async {
        Self.logger.debug("Would remove notifications for plan \(planID, privacy: .public)")
    }
}
