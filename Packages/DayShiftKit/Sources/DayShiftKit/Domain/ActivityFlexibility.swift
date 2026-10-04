import Foundation

/// How much DayShift may change a plan when suggesting options.
/// The rules that need the plan's own times are checked by `PlannedActivity`.
public struct ActivityFlexibility: Hashable, Sendable {
    /// The time the plan may move within. nil means the time is fixed.
    public let movableWindow: DateInterval?
    public let allowsPlaceChange: Bool

    public static let fixed = ActivityFlexibility(movableWindow: nil, allowsPlaceChange: false)

    public init(movableWindow: DateInterval?, allowsPlaceChange: Bool) {
        self.movableWindow = movableWindow
        self.allowsPlaceChange = allowsPlaceChange
    }

    public var allowsAnyChange: Bool {
        movableWindow != nil || allowsPlaceChange
    }
}
