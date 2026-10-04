import Foundation

/// Whether a plan happens at a place or online.
public enum ActivityMode: String, CaseIterable, Codable, Hashable, Sendable {
    case inPerson
    case online
}
