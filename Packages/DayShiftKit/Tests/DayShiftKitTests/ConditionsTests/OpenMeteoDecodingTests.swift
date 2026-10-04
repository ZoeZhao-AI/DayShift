import Foundation
import Testing
@testable import DayShiftKit

struct OpenMeteoDecodingTests {
    @Test("An Open-Meteo forecast for Enmore Park becomes 24 hourly conditions")
    func forecastBecomesTwentyFourHours() throws {
        let day = try LinsThursday()

        let forecasts = try OpenMeteoDecoder.forecasts(
            weatherJSON: OpenMeteoSamples.enmoreParkWeather,
            airQualityJSON: OpenMeteoSamples.enmoreParkAirQuality,
            fetchedAt: day.now
        )

        let forecast = try #require(forecasts.first)
        #expect(forecasts.count == 1)
        #expect(forecast.fetchedAt == day.now)
        #expect(forecast.hours.count == 24)
        #expect(forecast.hours.first?.time == day.time(0))
        #expect(forecast.hours.last?.time == day.time(23))
    }

    @Test("Weather and air quality are joined by hour")
    func weatherAndAirQualityJoinedByHour() throws {
        let day = try LinsThursday()

        let forecast = try #require(try OpenMeteoDecoder.forecasts(
            weatherJSON: OpenMeteoSamples.enmoreParkWeather,
            airQualityJSON: OpenMeteoSamples.enmoreParkAirQuality,
            fetchedAt: day.now
        ).first)

        // Smoke until 10 am: poor at 9 am, good at 10 am.
        let nineAM = try #require(forecast.hours.first { $0.time == day.time(9) })
        let tenAM = try #require(forecast.hours.first { $0.time == day.time(10) })
        #expect(nineAM.pm25 == 60 && nineAM.airQuality == .poor)
        #expect(tenAM.pm25 == 12 && tenAM.airQuality == .good)

        // Every hour matches Lin's Thursday, weather and air quality together.
        #expect(forecast.hours == (try day.hourlyConditions()))
    }
}
