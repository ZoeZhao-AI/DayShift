//
//  ContentView.swift
//  DayShift
//
//  Created by Alex W on 3/10/2026.
//

import DayShiftKit
import os
import SwiftUI
import WidgetKit

/// Temporary screen for the shared-store spike (Section 9, Step 2),
/// now saving through ActivityRepository, plus the forecast check for
/// Step 5 (5.1). Replaced by Today in Step 3.
struct ContentView: View {
    private static let logger = Logger(subsystem: "com.utsstudent.zhaoziying.DayShift", category: "Conditions")

    /// Two of Lin's places, about 1 km apart.
    private static let forecastPlaces: [(name: String, coordinate: Coordinate)] = [
        ("Enmore Park", Coordinate(latitude: -33.9035, longitude: 151.1685)),
        ("Newtown Library", Coordinate(latitude: -33.8975, longitude: 151.1790))
    ]

    @State private var resultMessage: String?
    @State private var forecastMessage: String?
    /// Kept for the screen's lifetime, so a second tap within the hour uses the cache.
    @State private var conditionsService = OpenMeteoConditionsService()

    var body: some View {
        VStack(spacing: 16) {
            Button("Save test plan") {
                Task { await saveTestPlan() }
            }
            .buttonStyle(.borderedProminent)

            if let resultMessage {
                Text(resultMessage)
                    .multilineTextAlignment(.center)
            }

            Button("Check forecast") {
                Task { await checkForecast() }
            }
            .buttonStyle(.bordered)

            if let forecastMessage {
                Text(forecastMessage)
                    .font(.footnote.monospacedDigit())
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
    }

    /// Fetches today's forecast for two places and shows the current hour at each.
    /// Every hour is also written to the log (category "Conditions").
    @MainActor
    private func checkForecast() async {
        let now = Date()
        do {
            let forecasts = try await conditionsService.forecast(
                for: Self.forecastPlaces.map(\.coordinate),
                on: now
            )
            forecastMessage = Self.forecastPlaces.map { place in
                guard let forecast = forecasts[place.coordinate] else {
                    return "\(place.name): no forecast returned."
                }
                Self.log(forecast, for: place.name)
                guard let hour = forecast.hours.last(where: { $0.time <= now }) else {
                    return "\(place.name): no hour covers now (\(forecast.hours.count) hours)."
                }
                return """
                    \(place.name) · \(hour.time.formatted(date: .omitted, time: .shortened))
                    \(Self.describe(hour))
                    \(forecast.hours.count) hours · fetched \(forecast.fetchedAt.formatted(date: .omitted, time: .standard))
                    """
            }.joined(separator: "\n\n")
        } catch {
            let localized = error as? LocalizedError
            forecastMessage = [
                localized?.errorDescription ?? "The forecast couldn't be loaded.",
                localized?.recoverySuggestion ?? "Please try again."
            ].joined(separator: "\n")
        }
    }

    private static func describe(_ hour: HourlyConditions) -> String {
        "\(hour.temperatureC.formatted())°C (feels \(hour.apparentTemperatureC.formatted())°C) · "
            + "rain \(hour.precipitationProbability)% · UV \(hour.uvIndex.formatted()) · "
            + "gusts \(hour.windGustsKmh.formatted()) km/h · PM2.5 \(hour.pm25.formatted()) (\(hour.airQuality.rawValue))"
    }

    private static func log(_ forecast: ConditionsForecast, for name: String) {
        for hour in forecast.hours {
            logger.info("\(name, privacy: .public) \(hour.time.formatted(date: .abbreviated, time: .shortened), privacy: .public): \(describe(hour), privacy: .public)")
        }
    }

    /// Saves a 30-minute online Client call starting now, then reloads the widget.
    @MainActor
    private func saveTestPlan() async {
        do {
            let repository = CoreDataActivityRepository(stack: try CoreDataStack())
            let clientCall = try PlannedActivity(
                typeID: ActivityCatalogue.clientMeeting.id,
                title: "Client call",
                start: Date(),
                durationMinutes: 30,
                place: nil,
                mode: .online,
                flexibility: .fixed
            )
            try await repository.save(clientCall)
            WidgetCenter.shared.reloadAllTimelines()
            resultMessage = "Saved \"Client call\". Check the widget."
        } catch {
            let localized = error as? LocalizedError
            resultMessage = [
                localized?.errorDescription ?? "Your test plan couldn't be saved.",
                localized?.recoverySuggestion ?? "Please try again."
            ].joined(separator: "\n")
        }
    }
}

#Preview {
    ContentView()
}
