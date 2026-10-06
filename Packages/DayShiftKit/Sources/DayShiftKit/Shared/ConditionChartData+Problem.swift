import Foundation

extension ConditionChartData {
    /// The chart for a plan whose conditions at the place are a problem:
    /// the first of the activity's conditions above Lin's limit during the
    /// plan (outdoor), or the outside temperature against the place's limit
    /// (indoor without AC). Shared by Plan Detail and plan-affected
    /// notifications. nil if there is no problem at the place, or no hours.
    public static func problemChart(
        for plan: PlannedActivity,
        check: PlanCheck?,
        forecast: ConditionsForecast,
        preferences: ComfortPreferences,
        calendar: Calendar
    ) -> ConditionChartData? {
        guard let check, let place = plan.place,
              check.findings.contains(where: { $0.factor == .conditions && $0.severity == .problem })
        else { return nil }

        let range = chartRange(for: plan, calendar: calendar)
        let hours = forecast.hours.filter { $0.time >= range.start && $0.time < range.end }
        guard !hours.isEmpty else { return nil }

        if place.isIndoor {
            guard !place.isCooled, let limit = place.uncooledHeatLimitC else { return nil }
            return ConditionChartData(
                conditionName: "Temperature outside",
                valueName: "Outside (°C)",
                points: hours.map { Point(time: $0.time, value: $0.temperatureC) },
                limit: limit,
                limitLabel: "Too hot above \(Int(limit.rounded()))°C"
            )
        }

        let planHours = forecast.conditions(during: plan.interval)
        let sensitivities = ActivityCatalogue.type(withID: plan.typeID)?.sensitivities
            ?? Set(ConditionSensitivity.allCases)
        for sensitivity in ConditionSensitivity.allCases where sensitivities.contains(sensitivity) {
            guard let measure = measure(sensitivity, preferences: preferences),
                  planHours.contains(where: { measure.value($0) > measure.limit })
            else { continue }
            return ConditionChartData(
                conditionName: measure.name,
                valueName: measure.valueName,
                points: hours.map { Point(time: $0.time, value: measure.value($0)) },
                limit: measure.limit,
                limitLabel: measure.limitLabel
            )
        }
        return nil
    }

    /// From an hour before the plan to an hour after it, at least 6 hours wide,
    /// so the chart shows when the problem ends.
    public static func chartRange(for plan: PlannedActivity, calendar: Calendar) -> DateInterval {
        let hourStart = calendar.dateInterval(of: .hour, for: plan.start)?.start ?? plan.start
        let start = hourStart.addingTimeInterval(-3600)
        let end = max(plan.end.addingTimeInterval(3600), start.addingTimeInterval(6 * 3600))
        return DateInterval(start: start, end: end)
    }

    private struct Measure {
        let name: String
        let valueName: String
        let limit: Double
        let limitLabel: String
        let value: (HourlyConditions) -> Double
    }

    private static func measure(_ sensitivity: ConditionSensitivity, preferences: ComfortPreferences) -> Measure? {
        switch sensitivity {
        case .heat:
            let limit = preferences.maxApparentTemperatureC
            return Measure(name: "Feels-like temperature", valueName: "Feels like (°C)", limit: limit,
                           limitLabel: "Your limit \(Int(limit.rounded()))°C", value: \.apparentTemperatureC)
        case .poorAirQuality:
            let category = preferences.worstAcceptableAirQuality
            guard let limit = category.pm25UpperBound else { return nil }
            return Measure(name: "Air quality", valueName: "PM2.5 (µg/m³)", limit: limit,
                           limitLabel: "Your limit (\(category.name))", value: \.pm25)
        case .uv:
            let limit = preferences.maxUVIndex
            return Measure(name: "UV", valueName: "UV index", limit: limit,
                           limitLabel: "Your limit \(Int(limit.rounded()))", value: \.uvIndex)
        case .wind:
            let limit = preferences.maxWindGustsKmh
            return Measure(name: "Wind gusts", valueName: "Gusts (km/h)", limit: limit,
                           limitLabel: "Your limit \(Int(limit.rounded())) km/h", value: \.windGustsKmh)
        case .rain:
            let limit = Double(preferences.maxRainProbability)
            return Measure(name: "Chance of rain", valueName: "Rain (%)", limit: limit,
                           limitLabel: "Your limit \(preferences.maxRainProbability)%",
                           value: { Double($0.precipitationProbability) })
        }
    }
}
