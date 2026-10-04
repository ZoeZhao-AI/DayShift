import Foundation
import os

/// Weather and air quality from Open-Meteo, using URLSession only.
/// - Coordinates are rounded to 2 decimal places, and all places missing from
///   the cache are fetched in one request per endpoint.
/// - Forecasts are cached for 1 hour per day and rounded coordinate.
/// - After each successful fetch, the cache is saved to the App Group container
///   as JSON and loaded again on the next launch.
public actor OpenMeteoConditionsService: ConditionsService {
    static let forecastURL = URL(string: "https://api.open-meteo.com/v1/forecast")!
    static let airQualityURL = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
    static let weatherVariables = "temperature_2m,apparent_temperature,precipitation_probability,uv_index,wind_gusts_10m"
    static let airQualityVariables = "pm2_5"
    static let cacheDuration: TimeInterval = 60 * 60
    static let savedFileName = "LastConditions.json"

    private static let logger = Logger(subsystem: "com.utsstudent.zhaoziying.DayShift", category: "Conditions")
    private static let sydney: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }()

    private struct CacheKey: Hashable {
        /// "yyyy-MM-dd" in Sydney.
        let day: String
        let coordinate: Coordinate
    }

    private struct SavedForecast: Codable {
        let day: String
        let latitude: Double
        let longitude: Double
        let forecast: ConditionsForecast
    }

    private let session: URLSession
    private let savedFileURL: URL?
    private let now: @Sendable () -> Date
    private var cache: [CacheKey: ConditionsForecast]

    public init(
        session: URLSession = .shared,
        appGroupIdentifier: String = AppGroup.identifier,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.now = now
        savedFileURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(Self.savedFileName)
        cache = Self.loadSavedForecasts(from: savedFileURL)
    }

    public func forecast(for coordinates: [Coordinate], on day: Date) async throws -> [Coordinate: ConditionsForecast] {
        let dayString = Self.dayString(for: day)
        let rounded = coordinates.map(Self.rounded)
        var uniqueRounded: [Coordinate] = []
        for coordinate in rounded where !uniqueRounded.contains(coordinate) {
            uniqueRounded.append(coordinate)
        }

        let requestTime = now()
        let missing = uniqueRounded.filter { coordinate in
            guard let cached = cache[CacheKey(day: dayString, coordinate: coordinate)] else { return true }
            return requestTime.timeIntervalSince(cached.fetchedAt) >= Self.cacheDuration
        }

        if !missing.isEmpty {
            let fetched = try await Self.fetch(missing, day: dayString, fetchedAt: requestTime, session: session)
            for (coordinate, forecast) in zip(missing, fetched) {
                cache[CacheKey(day: dayString, coordinate: coordinate)] = forecast
            }
            saveForecasts(today: Self.dayString(for: requestTime))
        }

        var result: [Coordinate: ConditionsForecast] = [:]
        for (original, roundedCoordinate) in zip(coordinates, rounded) {
            result[original] = cache[CacheKey(day: dayString, coordinate: roundedCoordinate)]
        }
        return result
    }

    // MARK: Fetching

    /// One request per endpoint for all coordinates; results in the same order.
    private static func fetch(
        _ coordinates: [Coordinate],
        day: String,
        fetchedAt: Date,
        session: URLSession
    ) async throws -> [ConditionsForecast] {
        async let weatherJSON = data(
            from: url(forecastURL, variables: weatherVariables, coordinates: coordinates, day: day),
            session: session
        )
        async let airQualityJSON = data(
            from: url(airQualityURL, variables: airQualityVariables, coordinates: coordinates, day: day),
            session: session
        )
        let (weather, airQuality) = try await (weatherJSON, airQualityJSON)

        do {
            let forecasts = try OpenMeteoDecoder.forecasts(
                weatherJSON: weather,
                airQualityJSON: airQuality,
                fetchedAt: fetchedAt
            )
            guard forecasts.count == coordinates.count else {
                throw OpenMeteoDecodingError.locationCountMismatch
            }
            return forecasts
        } catch {
            throw ConditionsServiceError.invalidResponse(underlying: error)
        }
    }

    private static func data(from url: URL, session: URLSession) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ConditionsServiceError.unreachable(underlying: error)
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw ConditionsServiceError.requestFailed(statusCode: statusCode)
        }
        return data
    }

    static func url(_ base: URL, variables: String, coordinates: [Coordinate], day: String) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: coordinates.map { String(format: "%.2f", $0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: coordinates.map { String(format: "%.2f", $0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: variables),
            URLQueryItem(name: "timezone", value: "Australia/Sydney"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "start_date", value: day),
            URLQueryItem(name: "end_date", value: day)
        ]
        return components.url!
    }

    // MARK: Helpers

    static func rounded(_ coordinate: Coordinate) -> Coordinate {
        Coordinate(
            latitude: (coordinate.latitude * 100).rounded() / 100,
            longitude: (coordinate.longitude * 100).rounded() / 100
        )
    }

    static func dayString(for date: Date) -> String {
        let components = sydney.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    // MARK: Saving

    /// Saves forecasts for today and later; older days are dropped so the file
    /// stays small. A failure is logged and doesn't affect the forecast.
    private func saveForecasts(today: String) {
        guard let savedFileURL else {
            Self.logger.error("Couldn't save the forecast: the App Group container is unavailable.")
            return
        }
        let saved = cache
            .filter { $0.key.day >= today }
            .map { key, forecast in
                SavedForecast(
                    day: key.day,
                    latitude: key.coordinate.latitude,
                    longitude: key.coordinate.longitude,
                    forecast: forecast
                )
            }
        do {
            try JSONEncoder().encode(saved).write(to: savedFileURL, options: .atomic)
        } catch {
            Self.logger.error("Couldn't save the forecast: \(String(describing: error), privacy: .public)")
        }
    }

    /// The forecasts saved by the last successful fetch, or none if there is no
    /// file or it can't be read.
    private static func loadSavedForecasts(from url: URL?) -> [CacheKey: ConditionsForecast] {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let saved = try JSONDecoder().decode([SavedForecast].self, from: Data(contentsOf: url))
            return Dictionary(
                saved.map { (CacheKey(day: $0.day, coordinate: Coordinate(latitude: $0.latitude, longitude: $0.longitude)), $0.forecast) },
                uniquingKeysWith: { _, latest in latest }
            )
        } catch {
            logger.error("Couldn't read the saved forecast: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }
}
