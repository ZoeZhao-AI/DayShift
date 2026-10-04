import Foundation

/// What an activity is for. Wording matches the prototype.
public enum ActivityPurpose: String, CaseIterable, Codable, Hashable, Sendable {
    case exercise
    case work
    case socialising
    case relaxationAndCreative
    case errands
}
