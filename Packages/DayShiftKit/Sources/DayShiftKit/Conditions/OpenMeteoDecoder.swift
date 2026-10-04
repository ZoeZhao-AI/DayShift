import Foundation

/// Why an Open-Meteo response couldn't be turned into forecasts.
enum OpenMeteoDecodingError: Error, Equatable {
    /// The weather and air-quality responses describe a different number of places.
    case locationCountMismatch
    /// An hourly array has a different length from its `time` array.
    case hourlyLengthMismatch
}

/// Turns Open-Meteo forecast and air-quality responses into domain forecasts.
/// Expects `timeformat=unixtime`. One location returns an object, several
/// return a list; both are accepted. Results are in request order, because
/// Open-Meteo returns grid-point coordinates rather than the requested ones.
enum OpenMeteoDecoder {
    /// One forecast per location, in request order. Weather and air quality are
    /// joined by time; an hour missing from either, or with a null value, is left out.
    static func forecasts(weatherJSON: Data, airQualityJSON: Data, fetchedAt: Date) throws -> [ConditionsForecast] {
        let weatherLocations = try locations(WeatherLocation.self, from: weatherJSON)
        let airQualityLocations = try locations(AirQualityLocation.self, from: airQualityJSON)
        guard weatherLocations.count == airQualityLocations.count else {
            throw OpenMeteoDecodingError.locationCountMismatch
        }

        return try zip(weatherLocations, airQualityLocations).map { weather, airQuality in
            ConditionsForecast(
                latitude: weather.latitude,
                longitude: weather.longitude,
                fetchedAt: fetchedAt,
                hours: try hours(weather: weather.hourly, airQuality: airQuality.hourly)
            )
        }
    }

    private static func hours(weather: WeatherHourly, airQuality: AirQualityHourly) throws -> [HourlyConditions] {
        let weatherCount = weather.time.count
        guard [
            weather.temperature.count, weather.apparentTemperature.count,
            weather.precipitationProbability.count, weather.uvIndex.count, weather.windGusts.count
        ].allSatisfy({ $0 == weatherCount }),
            airQuality.pm25.count == airQuality.time.count
        else {
            throw OpenMeteoDecodingError.hourlyLengthMismatch
        }

        let pm25ByTime = Dictionary(
            zip(airQuality.time, airQuality.pm25).compactMap { time, pm25 in pm25.map { (time, $0) } },
            uniquingKeysWith: { first, _ in first }
        )

        return try weather.time.indices.compactMap { index in
            let time = weather.time[index]
            guard let temperature = weather.temperature[index],
                  let apparentTemperature = weather.apparentTemperature[index],
                  let precipitationProbability = weather.precipitationProbability[index],
                  let uvIndex = weather.uvIndex[index],
                  let windGusts = weather.windGusts[index],
                  let pm25 = pm25ByTime[time]
            else { return nil }

            return try HourlyConditions(
                time: Date(timeIntervalSince1970: time),
                temperatureC: temperature,
                apparentTemperatureC: apparentTemperature,
                precipitationProbability: Int(precipitationProbability.rounded()),
                uvIndex: uvIndex,
                windGustsKmh: windGusts,
                pm25: pm25
            )
        }
    }

    /// A list for several locations, an object for one.
    private static func locations<Location: Decodable>(_ type: Location.Type, from data: Data) throws -> [Location] {
        let decoder = JSONDecoder()
        let firstCharacter = data.first { !Character(UnicodeScalar($0)).isWhitespace }
        if firstCharacter == UInt8(ascii: "[") {
            return try decoder.decode([Location].self, from: data)
        }
        return [try decoder.decode(Location.self, from: data)]
    }
}

// MARK: - Response shapes

private struct WeatherLocation: Decodable {
    let latitude: Double
    let longitude: Double
    let hourly: WeatherHourly
}

private struct WeatherHourly: Decodable {
    let time: [TimeInterval]
    let temperature: [Double?]
    let apparentTemperature: [Double?]
    /// Whole percentages in practice; decoded as Double so a decimal can't break decoding.
    let precipitationProbability: [Double?]
    let uvIndex: [Double?]
    let windGusts: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case uvIndex = "uv_index"
        case windGusts = "wind_gusts_10m"
    }
}

private struct AirQualityLocation: Decodable {
    let hourly: AirQualityHourly
}

private struct AirQualityHourly: Decodable {
    let time: [TimeInterval]
    let pm25: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case pm25 = "pm2_5"
    }
}
