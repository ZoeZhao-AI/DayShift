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
