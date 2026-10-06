import Foundation

/// Schedules DayShift's local notifications (Section 6.3). Scheduling a
/// notification for a plan replaces the earlier one of the same kind.
public protocol NotificationScheduling {
    /// Situation A: "Leave in 10 min for Focus work".
    func scheduleLeaveReminder(_ reminder: LeaveReminder) async throws

    /// Situation B: "Your 7:00 am run is affected".
    func schedulePlanAffectedAlert(_ alert: PlanAffectedAlert) async throws

    /// Removes the plan's pending and delivered notifications of both kinds.
    func removeNotifications(forPlan planID: UUID) async
}

/// The `upcomingPlan` category's actions (6.3), shared by the app and the
/// Notification Content Extension. Plain strings: DayShiftKit doesn't import
/// UserNotifications (1.3).
public enum NotificationAction: String, CaseIterable, Sendable {
    /// Opens the app at the plan's options.
    case seeOptions
    case keepPlan
    /// Leave reminders only.
    case gotIt

    public var title: String {
        switch self {
        case .seeOptions: return "See options"
        case .keepPlan: return "Keep my plan"
        case .gotIt: return "Got it"
        }
    }

    /// Whether choosing it opens DayShift.
    public var opensApp: Bool {
        self == .seeOptions
    }
}

/// Identifiers from Section 6.3, so a plan's notifications can be replaced or removed.
public enum NotificationIdentifier {
    /// The category both situations use; the content extension is registered for it.
    public static let category = "upcomingPlan"

    public static func leaveReminder(planID: UUID) -> String {
        "leave-\(planID.uuidString)"
    }

    public static func planAffected(planID: UUID) -> String {
        "affected-\(planID.uuidString)"
    }
}

/// Everything needed to remind Lin when to leave for an in-person plan.
public struct LeaveReminder: Hashable, Sendable {
    public let planID: UUID
    public let planTitle: String
    public let placeName: String
    public let travel: TravelEstimate
    public let leaveBy: Date
    /// When the reminder fires: `leaveReminderMinutes` before `leaveBy`.
    public let fireAt: Date
    public let findings: [PlanFinding]

    public init(
        planID: UUID,
        planTitle: String,
        placeName: String,
        travel: TravelEstimate,
        leaveBy: Date,
        fireAt: Date,
        findings: [PlanFinding]
    ) {
        self.planID = planID
        self.planTitle = planTitle
        self.placeName = placeName
        self.travel = travel
        self.leaveBy = leaveBy
        self.fireAt = fireAt
        self.findings = findings
    }
}

/// Everything needed to tell Lin a plan is affected by a new problem.
public struct PlanAffectedAlert: Hashable, Sendable {
    public let planID: UUID
    public let planTitle: String
    public let planStart: Date
    /// The problem in plain language, e.g. "Smoke until 10 am."
    public let reason: String
    /// The reasons this alert covers, e.g. ["poorAirQuality"]; each is alerted once.
    public let reasonKeys: Set<String>
    public let findings: [PlanFinding]

    public init(
        planID: UUID,
        planTitle: String,
        planStart: Date,
        reason: String,
        reasonKeys: Set<String>,
        findings: [PlanFinding]
    ) {
        self.planID = planID
        self.planTitle = planTitle
        self.planStart = planStart
        self.reason = reason
        self.reasonKeys = reasonKeys
        self.findings = findings
    }
}
