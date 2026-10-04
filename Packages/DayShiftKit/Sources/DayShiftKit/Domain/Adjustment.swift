import Foundation

/// The main change an option makes to a plan.
public enum Adjustment: Hashable, Sendable {
    case shiftTime(newStart: Date)
    case changePlace(Place)
}
