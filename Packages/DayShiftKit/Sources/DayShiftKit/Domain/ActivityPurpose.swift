import Foundation

/// What an activity is for.
public enum ActivityPurpose: String, CaseIterable, Codable, Hashable, Sendable {
    case exercise
    case work
    case social
    case leisure
    case errand
}
