import Foundation
import Testing
@testable import DayShiftKit

/// A plain object with the same key paths as `ActivityEntity`, so the
/// predicates can be evaluated without Core Data.
private final class StoredPlan: NSObject {
    @objc let start: Date
    @objc let statusRaw: String
    @objc let checkStatusRaw: String?

    init(start: Date, status: PlanStatus, checkStatus: PlanCheck.Status? = nil) {
        self.start = start
        self.statusRaw = status.rawValue
        self.checkStatusRaw = checkStatus?.rawValue
    }
}

struct ActivityQueryTests {
    @Test("Checkable plans include upcoming planned and adjusted plans, and exclude started and cancelled ones")
    func checkablePlansAreUpcomingAndNotCancelled() {
        let now = LinsThursday.time(6, 40)
        let predicate = ActivityQuery.checkablePlans(on: now, now: now, calendar: LinsThursday.sydney)

        let upcomingRun = StoredPlan(start: LinsThursday.time(7), status: .planned)
        let movedGroceryRun = StoredPlan(start: LinsThursday.time(18, 30), status: .adjusted)
        let startedWalk = StoredPlan(start: LinsThursday.time(6), status: .planned)
        let cancelledCoffee = StoredPlan(start: LinsThursday.time(9), status: .cancelled)

        #expect(predicate.evaluate(with: upcomingRun))
        #expect(predicate.evaluate(with: movedGroceryRun))
        #expect(!predicate.evaluate(with: startedWalk))
        #expect(!predicate.evaluate(with: cancelledCoffee))
    }

    @Test("A cancelled plan never needs attention")
    func cancelledPlanNeverNeedsAttention() {
        let predicate = ActivityQuery.plansNeedingAttention(on: LinsThursday.time(6, 40), calendar: LinsThursday.sydney)

        let smokyRun = StoredPlan(start: LinsThursday.time(7), status: .planned, checkStatus: .needsAttention)
        let cancelledSmokyRun = StoredPlan(start: LinsThursday.time(7), status: .cancelled, checkStatus: .needsAttention)

        #expect(predicate.evaluate(with: smokyRun))
        #expect(!predicate.evaluate(with: cancelledSmokyRun))
    }
}
