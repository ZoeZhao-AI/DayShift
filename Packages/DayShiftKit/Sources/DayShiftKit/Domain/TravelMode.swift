import Foundation

/// How Lin gets between places.
public enum TravelMode: String, CaseIterable, Codable, Hashable, Sendable {
    case walking
    case publicTransport
    case driving
}
