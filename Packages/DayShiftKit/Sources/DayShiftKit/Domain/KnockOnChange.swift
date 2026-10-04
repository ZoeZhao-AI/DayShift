import Foundation

/// Another plan that moves so an option fits. At most one per option.
public struct KnockOnChange: Hashable, Sendable {
    public let planID: UUID
    public let title: String
    public let newStart: Date

    public init(planID: UUID, title: String, newStart: Date) {
        self.planID = planID
        self.title = title
        self.newStart = newStart
    }
}
