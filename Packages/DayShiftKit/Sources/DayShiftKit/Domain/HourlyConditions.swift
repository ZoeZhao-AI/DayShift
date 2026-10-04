import Foundation

/// Weather and air quality for one hour at one place.
public struct HourlyConditions: Hashable, Sendable {
    public static let precipitationProbabilityRange = 0...100

    /// Start of the hour.
    public let time: Date
    public let temperatureC: Double
    /// "Feels like" temperature.
    public let apparentTemperatureC: Double
    /// Chance of rain, 0–100 %.
    public let precipitationProbability: Int
    public let uvIndex: Double
    public let windGustsKmh: Double
    /// PM2.5 in µg/m³.
    public let pm25: Double

    public init(
        time: Date,
        temperatureC: Double,
        apparentTemperatureC: Double,
        precipitationProbability: Int,
        uvIndex: Double,
        windGustsKmh: Double,
        pm25: Double
    ) throws {
        guard Self.precipitationProbabilityRange.contains(precipitationProbability) else {
            throw HourlyConditionsError.precipitationProbabilityOutOfRange
        }
        self.time = time
        self.temperatureC = temperatureC
        self.apparentTemperatureC = apparentTemperatureC
        self.precipitationProbability = precipitationProbability
        self.uvIndex = uvIndex
        self.windGustsKmh = windGustsKmh
        self.pm25 = pm25
    }

    public var airQuality: AirQualityCategory {
        AirQualityCategory(pm25: pm25)
    }
}

public enum HourlyConditionsError: Error, Equatable {
    case precipitationProbabilityOutOfRange
}

/// Saved as JSON with the last forecast. Decoding runs the same checks as
/// `init(time:temperatureC:…)`.
extension HourlyConditions: Codable {
    private enum CodingKeys: String, CodingKey {
        case time
        case temperatureC
        case apparentTemperatureC
        case precipitationProbability
        case uvIndex
        case windGustsKmh
        case pm25
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            time: container.decode(Date.self, forKey: .time),
            temperatureC: container.decode(Double.self, forKey: .temperatureC),
            apparentTemperatureC: container.decode(Double.self, forKey: .apparentTemperatureC),
            precipitationProbability: container.decode(Int.self, forKey: .precipitationProbability),
            uvIndex: container.decode(Double.self, forKey: .uvIndex),
            windGustsKmh: container.decode(Double.self, forKey: .windGustsKmh),
            pm25: container.decode(Double.self, forKey: .pm25)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)
        try container.encode(temperatureC, forKey: .temperatureC)
        try container.encode(apparentTemperatureC, forKey: .apparentTemperatureC)
        try container.encode(precipitationProbability, forKey: .precipitationProbability)
        try container.encode(uvIndex, forKey: .uvIndex)
        try container.encode(windGustsKmh, forKey: .windGustsKmh)
        try container.encode(pm25, forKey: .pm25)
    }
}
