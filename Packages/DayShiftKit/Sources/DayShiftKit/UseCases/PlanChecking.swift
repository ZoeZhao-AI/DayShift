import Foundation

/// Checks one plan and saves the result. Lets PlanActivityUseCase run the
/// check after saving while depending only on a protocol (Section 1.3).
/// CheckUpcomingPlansUseCase provides it.
public protocol PlanChecking {
    func checkPlan(_ plan: PlannedActivity, now: Date) async throws -> PlanCheck
}
