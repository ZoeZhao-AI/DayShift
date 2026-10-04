import Foundation

/// A condition that can make an activity uncomfortable or unsafe.
public enum ConditionSensitivity: String, CaseIterable, Codable, Hashable, Sendable {
    case heat
    case poorAirQuality
    case uv
    case wind
    case rain
}
