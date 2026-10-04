import Foundation
@testable import DayShiftKit

/// Records the plans it was asked to check and returns a check with no
/// findings. Set `errorToThrow` to make every check fail.
final class MockPlanChecker: PlanChecking {
    var errorToThrow: Error?
    private(set) var checkedPlans: [PlannedActivity] = []

    func checkPlan(_ plan: PlannedActivity, now: Date) async throws -> PlanCheck {
        checkedPlans.append(plan)
        if let errorToThrow { throw errorToThrow }
        return PlanCheck(planID: plan.id, checkedAt: now, leaveBy: nil, travel: nil, findings: [])
    }
}
