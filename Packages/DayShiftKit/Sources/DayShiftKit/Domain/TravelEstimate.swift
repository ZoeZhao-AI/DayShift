import Foundation

/// How long it takes to get to a plan.
public struct TravelEstimate: Hashable, Sendable {
    public let minutes: Int
    public let mode: TravelMode

    public init(minutes: Int, mode: TravelMode) {
        self.minutes = minutes
        self.mode = mode
    }

    /// Travel times come from straight-line distance, so they are always estimates.
    public var isEstimate: Bool { true }
}
