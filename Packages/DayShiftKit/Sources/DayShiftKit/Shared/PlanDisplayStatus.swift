import Foundation

/// What a plan's status says on Today, Plan Detail and the widget. Once a plan has
/// started Lin can't change it (3.4), so only upcoming plans today show their
/// check. Plans on later days aren't checked until their day (7.4).
public enum PlanDisplayStatus: Equatable, Sendable {
    case looksGood
    case needsAttention
    /// Upcoming, with no saved check yet.
    case notCheckedYet
    /// Started; its last check isn't shown.
    case inProgress
    /// Ended; its last check isn't shown.
    case done
    /// On a later day; it is checked on the day.
    case checkedOnTheDay

    public init(plan: PlannedActivity, check: PlanCheck?, now: Date, calendar: Calendar) {
        if plan.end <= now {
            self = .done
        } else if plan.start <= now {
            self = .inProgress
        } else if !calendar.isDate(plan.start, inSameDayAs: now) {
            self = .checkedOnTheDay
        } else {
            switch check?.overallStatus {
            case .needsAttention: self = .needsAttention
            case .looksGood: self = .looksGood
            case nil: self = .notCheckedYet
            }
        }
    }

    /// The status in words; with `symbolName` it is always shown as icon + words (7.4).
    public var text: String {
        switch self {
        case .looksGood: return "Looks good"
        case .needsAttention: return "Needs attention"
        case .notCheckedYet: return "Not checked yet"
        case .inProgress: return "In progress"
        case .done: return "Done"
        case .checkedOnTheDay: return "Checked on the day"
        }
    }

    /// The SF Symbol shown with `text`.
    public var symbolName: String {
        switch self {
        case .looksGood: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .notCheckedYet: return "clock"
        case .inProgress: return "play.circle"
        case .done: return "checkmark"
        case .checkedOnTheDay: return "calendar"
        }
    }

    /// The check to show for a plan: its saved check while it is upcoming
    /// today, otherwise none.
    public static func shownCheck(of plan: PlannedActivity, check: PlanCheck?, now: Date, calendar: Calendar) -> PlanCheck? {
        plan.start > now && calendar.isDate(plan.start, inSameDayAs: now) ? check : nil
    }
}
