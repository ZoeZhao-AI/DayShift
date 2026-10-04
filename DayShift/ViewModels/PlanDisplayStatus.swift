import DayShiftKit
import Foundation

/// What a plan's status says on Today and Plan Detail. Once a plan has
/// started Lin can't change it (3.4), so only upcoming plans show their check.
enum PlanDisplayStatus: Equatable {
    case looksGood
    case needsAttention
    /// Upcoming, with no saved check yet.
    case notCheckedYet
    /// Started; its last check isn't shown.
    case inProgress
    /// Ended; its last check isn't shown.
    case done

    init(plan: PlannedActivity, check: PlanCheck?, now: Date) {
        if plan.end <= now {
            self = .done
        } else if plan.start <= now {
            self = .inProgress
        } else {
            switch check?.overallStatus {
            case .needsAttention: self = .needsAttention
            case .looksGood: self = .looksGood
            case nil: self = .notCheckedYet
            }
        }
    }

    /// The check to show for a plan: its saved check while it is upcoming, otherwise none.
    static func shownCheck(of plan: PlannedActivity, check: PlanCheck?, now: Date) -> PlanCheck? {
        plan.start > now ? check : nil
    }
}
