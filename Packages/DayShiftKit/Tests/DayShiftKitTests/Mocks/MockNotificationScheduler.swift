import Foundation
@testable import DayShiftKit

/// Records scheduled and removed notifications. Set `errorToThrow` to make
/// scheduling fail; removing never throws.
final class MockNotificationScheduler: NotificationScheduling {
    var errorToThrow: Error?

    private(set) var leaveReminders: [LeaveReminder] = []
    private(set) var planAffectedAlerts: [PlanAffectedAlert] = []
    private(set) var removedPlanIDs: [UUID] = []

    /// Identifiers scheduled so far, e.g. "leave-<planID>", in order.
    private(set) var scheduledIDs: [String] = []

    func scheduleLeaveReminder(_ reminder: LeaveReminder) async throws {
        if let errorToThrow { throw errorToThrow }
        leaveReminders.append(reminder)
        scheduledIDs.append(NotificationIdentifier.leaveReminder(planID: reminder.planID))
    }

    func schedulePlanAffectedAlert(_ alert: PlanAffectedAlert) async throws {
        if let errorToThrow { throw errorToThrow }
        planAffectedAlerts.append(alert)
        scheduledIDs.append(NotificationIdentifier.planAffected(planID: alert.planID))
    }

    func removeNotifications(forPlan planID: UUID) async {
        removedPlanIDs.append(planID)
    }
}
