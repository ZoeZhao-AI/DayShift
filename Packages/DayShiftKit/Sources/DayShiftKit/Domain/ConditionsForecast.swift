import Foundation

/// Hourly conditions for one place on one day.
public struct ConditionsForecast: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let fetchedAt: Date
    /// Sorted by time.
    public let hours: [HourlyConditions]

    public init(latitude: Double, longitude: Double, fetchedAt: Date, hours: [HourlyConditions]) {
        self.latitude = latitude
        self.longitude = longitude
        self.fetchedAt = fetchedAt
        self.hours = hours.sorted { $0.time < $1.time }
    }

    /// Every hour that overlaps the interval. A 7:00–7:45 run uses the
    /// 7 am hour; 1:00–5:00 pm uses the 1, 2, 3 and 4 pm hours.
    public func conditions(during interval: DateInterval) -> [HourlyConditions] {
        hours.filter { hour in
            hour.time < interval.end && hour.time.addingTimeInterval(60 * 60) > interval.start
        }
    }
}

/// Saved as JSON with the last forecast. Decoding goes through
/// `init(latitude:longitude:fetchedAt:hours:)`, so hours are checked and sorted.
extension ConditionsForecast: Codable {
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case fetchedAt
        case hours
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude),
            fetchedAt: try container.decode(Date.self, forKey: .fetchedAt),
            hours: try container.decode([HourlyConditions].self, forKey: .hours)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(fetchedAt, forKey: .fetchedAt)
        try container.encode(hours, forKey: .hours)
    }
}
