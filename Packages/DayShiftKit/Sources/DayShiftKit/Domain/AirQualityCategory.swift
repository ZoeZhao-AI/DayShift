import Foundation

/// Air quality from hourly PM2.5, ordered from best to worst.
public enum AirQualityCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case good
    case fair
    case poor
    case veryPoor
    case extremelyPoor

    // TODO (developer): confirm these against the NSW Air Quality Categories
    // before submission and cite the source in README.
    /// Thresholds in µg/m³: good < 25, fair < 50, poor < 100, veryPoor < 300,
    /// otherwise extremelyPoor.
    public init(pm25: Double) {
        switch pm25 {
        case ..<25: self = .good
        case ..<50: self = .fair
        case ..<100: self = .poor
        case ..<300: self = .veryPoor
        default: self = .extremelyPoor
        }
    }
}

extension AirQualityCategory {
    /// How the category is written for Lin, e.g. "Poor", "Very poor".
    public var name: String {
        switch self {
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .veryPoor: return "Very poor"
        case .extremelyPoor: return "Extremely poor"
        }
    }
}

extension AirQualityCategory: Comparable {
    /// A category is "less than" another when its air is better.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        Self.allCases.firstIndex(of: self)!
    }
}
