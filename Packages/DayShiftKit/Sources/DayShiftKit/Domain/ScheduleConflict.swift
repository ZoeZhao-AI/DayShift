import Foundation

/// Why a plan doesn't fit around another plan that day. Times are in minutes.
public enum ScheduleConflict: Hashable, Sendable {
    case overlaps(planID: UUID)
    case notEnoughGap(planID: UUID, available: Int, required: Int)
}
