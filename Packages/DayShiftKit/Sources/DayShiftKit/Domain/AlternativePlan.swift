import Foundation

/// An option DayShift suggests for a plan: a different time or place.
public struct AlternativePlan: Identifiable, Hashable, Sendable {
    public static let scoreRange = 0...100

    public let id: UUID
    public let planID: UUID
    public let adjustment: Adjustment
    public let knockOn: KnockOnChange?
    public let score: Int
    /// Why this option works, e.g. "Air quality returns to Good and UV is low."
    public let explanation: String
    /// How the rest of the day changes, e.g. "Grocery run moves from 5:30 to 6:30 pm.
    /// Your 11 am call is not affected."
    public let scheduleNote: String

    public init(
        id: UUID = UUID(),
        planID: UUID,
        adjustment: Adjustment,
        knockOn: KnockOnChange?,
        score: Int,
        explanation: String,
        scheduleNote: String
    ) throws {
        guard Self.scoreRange.contains(score) else {
            throw AlternativePlanError.scoreOutOfRange
        }
        self.id = id
        self.planID = planID
        self.adjustment = adjustment
        self.knockOn = knockOn
        self.score = score
        self.explanation = explanation
        self.scheduleNote = scheduleNote
    }
}

public enum AlternativePlanError: Error, Equatable {
    case scoreOutOfRange
}
