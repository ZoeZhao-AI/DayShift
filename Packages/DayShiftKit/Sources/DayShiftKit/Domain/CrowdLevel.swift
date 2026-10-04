import Foundation

/// How busy a place usually is. Always shown as an estimate.
public enum CrowdLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case quiet
    case moderate
    case busy
}
