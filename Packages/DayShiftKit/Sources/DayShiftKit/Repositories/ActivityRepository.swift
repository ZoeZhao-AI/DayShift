import Foundation

/// Reads and saves Lin's plans and their checks.
public protocol ActivityRepository {
    /// Plans on the day of `day` that are not cancelled, sorted by start.
    func plans(on day: Date) async throws -> [PlannedActivity]

    /// Today's plans that haven't started and are not cancelled.
    func checkablePlans(on day: Date, now: Date) async throws -> [PlannedActivity]

    /// Plans that are not cancelled and overlap `interval`, leaving out `ids`.
    func plans(overlapping interval: DateInterval, excluding ids: Set<UUID>) async throws -> [PlannedActivity]

    /// Adds the plan, or replaces the saved plan with the same id.
    func save(_ plan: PlannedActivity) async throws

    func delete(id: UUID) async throws

    func saveCheck(_ check: PlanCheck) async throws

    /// Records that Lin was alerted about these reasons for this plan.
    func markNotified(planID: UUID, reasonKeys: Set<String>) async throws

    /// Saves every changed plan and its record together; if any part fails,
    /// nothing changes.
    func applyAdjustment(changedPlans: [PlannedActivity], records: [AdjustmentRecord]) async throws
}
