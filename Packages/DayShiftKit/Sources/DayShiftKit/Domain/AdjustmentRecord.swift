import Foundation

/// A change Lin accepted, kept for each changed plan.
public struct AdjustmentRecord: Identifiable, Hashable, Sendable {
    /// Raw values are stored in Core Data as `kindRaw`.
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        case shiftTime
        case changePlace
    }

    public let id: UUID
    public let planID: UUID
    public let kind: Kind
    public let previousStart: Date
    public let newStart: Date
    /// nil when the plan was online.
    public let previousPlaceName: String?
    /// nil when the plan is online.
    public let newPlaceName: String?
    public let reason: String
    public let acceptedAt: Date

    public init(
        id: UUID = UUID(),
        planID: UUID,
        kind: Kind,
        previousStart: Date,
        newStart: Date,
        previousPlaceName: String?,
        newPlaceName: String?,
        reason: String,
        acceptedAt: Date
    ) {
        self.id = id
        self.planID = planID
        self.kind = kind
        self.previousStart = previousStart
        self.newStart = newStart
        self.previousPlaceName = previousPlaceName
        self.newPlaceName = newPlaceName
        self.reason = reason
        self.acceptedAt = acceptedAt
    }
}
