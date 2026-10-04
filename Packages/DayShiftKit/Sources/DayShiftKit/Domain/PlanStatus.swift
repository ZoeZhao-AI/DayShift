import Foundation

/// Where a plan is in its life. Raw values are stored in Core Data and
/// used by ActivityQuery.
public enum PlanStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case planned
    case adjusted
    case cancelled
}
