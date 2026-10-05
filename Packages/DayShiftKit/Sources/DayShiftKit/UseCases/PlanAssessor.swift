import Foundation

/// Assesses one plan against conditions, travel, opening hours and crowds
/// (Section 3.2). Shared by CheckUpcomingPlansUseCase and
/// SuggestAlternativesUseCase, so options pass exactly the same checks as plans.
struct PlanAssessor {
    /// Walking to and from the stop.
    static let publicTransportMinutesOutside = 4

    /// What a plan is assessed against.
    struct Context {
        let preferences: ComfortPreferences
        let home: Place?
        /// That day's plans that are not cancelled, to find each plan's previous plan.
        var dayPlans: [PlannedActivity]
        let forecasts: [Coordinate: ConditionsForecast]
    }

    /// A finding, and for problems the reason it is alerted under.
    struct Assessed {
        let finding: PlanFinding
        let reasonKey: String?
    }

    struct Assessment {
        let findings: [Assessed]
        let travel: TravelEstimate?
        let leaveBy: Date?
    }

    let travelTimes: TravelTimeService
    let calendar: Calendar

    // MARK: - Assessing one plan

    func assess(_ plan: PlannedActivity, context: Context) throws -> Assessment {
        guard let place = plan.place else {
            return Assessment(
                findings: [
                    Assessed(finding: try PlanFinding(factor: .conditions, severity: .fine, message: "Online, so the weather doesn't affect this plan."), reasonKey: nil),
                    Assessed(finding: try PlanFinding(factor: .travel, severity: .fine, message: "No travel needed."), reasonKey: nil),
                    Assessed(finding: try PlanFinding(factor: .openingHours, severity: .fine, message: "Always available."), reasonKey: nil),
                    Assessed(finding: try PlanFinding(factor: .crowds, severity: .fine, message: "Online, so crowds don't apply."), reasonKey: nil)
                ],
                travel: nil,
                leaveBy: nil
            )
        }

        let preferences = context.preferences
        let previous = context.dayPlans
            .filter { $0.id != plan.id && $0.end <= plan.start }
            .max { $0.end < $1.end }
        let origin = previous?.place ?? context.home
        let travel = origin.map {
            travelTimes.travelEstimate(from: $0.coordinate, to: place.coordinate, mode: preferences.travelMode)
        }
        let leaveBy = travel.map { plan.start.addingTimeInterval(-TimeInterval($0.minutes * 60)) }
        let forecast = context.forecasts[place.coordinate]

        var findings = try conditionFindings(plan, place: place, forecast: forecast, travel: travel, leaveBy: leaveBy, preferences: preferences)
        findings.append(try travelFinding(plan, travel: travel, leaveBy: leaveBy, previous: previous, context: context))
        findings.append(try openingHoursFinding(plan, place: place))
        findings.append(try crowdFinding(plan, place: place))
        return Assessment(findings: findings, travel: travel, leaveBy: leaveBy)
    }

    // MARK: Conditions

    private func conditionFindings(
        _ plan: PlannedActivity,
        place: Place,
        forecast: ConditionsForecast?,
        travel: TravelEstimate?,
        leaveBy: Date?,
        preferences: ComfortPreferences
    ) throws -> [Assessed] {
        let dayHours = forecast?.hours ?? []
        let planHours = forecast?.conditions(during: plan.interval) ?? []
        var findings: [Assessed] = []

        if planHours.isEmpty {
            findings.append(Assessed(
                finding: try PlanFinding(factor: .conditions, severity: .tip, message: "Weather and air quality for this time aren't available."),
                reasonKey: nil
            ))
        } else if !place.isIndoor {
            let sensitivities = ActivityCatalogue.type(withID: plan.typeID)?.sensitivities
                ?? Set(ConditionSensitivity.allCases)
            for sensitivity in ConditionSensitivity.allCases where sensitivities.contains(sensitivity) {
                if let message = outdoorProblem(sensitivity, planHours: planHours, dayHours: dayHours, plan: plan, preferences: preferences) {
                    findings.append(Assessed(
                        finding: try PlanFinding(factor: .conditions, severity: .problem, message: message),
                        reasonKey: sensitivity.rawValue
                    ))
                }
            }
        } else if !place.isCooled, let limit = place.uncooledHeatLimitC,
                  let message = uncooledHeatProblem(place: place, limit: limit, dayHours: dayHours, plan: plan) {
            findings.append(Assessed(
                finding: try PlanFinding(factor: .conditions, severity: .problem, message: message),
                reasonKey: ConditionSensitivity.heat.rawValue
            ))
        }

        // Outdoor plans are already checked hour by hour, so only indoor plans
        // check the trip there.
        if place.isIndoor, let travel, let leaveBy {
            findings += try onTheWayFindings(travel: travel, leaveBy: leaveBy, start: plan.start, forecast: forecast, preferences: preferences)
        }

        if findings.isEmpty {
            let message = place.isIndoor
                ? (place.isCooled ? "Indoors, air-conditioned." : "Indoors.")
                : "Conditions stay within your limits."
            findings.append(Assessed(finding: try PlanFinding(factor: .conditions, severity: .fine, message: message), reasonKey: nil))
        }
        return findings
    }

    /// e.g. "Smoke until 10 am. Air quality Poor, above your limit (Fair)."
    private func outdoorProblem(
        _ sensitivity: ConditionSensitivity,
        planHours: [HourlyConditions],
        dayHours: [HourlyConditions],
        plan: PlannedActivity,
        preferences: ComfortPreferences
    ) -> String? {
        guard let exceedance = Self.exceedance(sensitivity, in: planHours, preferences: preferences) else { return nil }
        guard sensitivity == .poorAirQuality else {
            return "\(exceedance.label), above your limit \(exceedance.limit)."
        }

        let firstBad = exceedance.firstTime
        let smoke: String
        if firstBad <= plan.start {
            let clearsAt = dayHours.first {
                $0.time > firstBad && $0.airQuality <= preferences.worstAcceptableAirQuality
            }?.time
            smoke = clearsAt.map { "Smoke until \(TimeText.shortTime($0, calendar: calendar))." }
                ?? "Smoke for the rest of the day."
        } else {
            smoke = "Smoke from \(TimeText.shortTime(firstBad, calendar: calendar))."
        }
        return "\(smoke) \(exceedance.label), above your limit \(exceedance.limit)."
    }

    /// Once the day's outdoor temperature passes the place's limit, the place
    /// is too hot from that hour to the end of the day.
    private func uncooledHeatProblem(place: Place, limit: Double, dayHours: [HourlyConditions], plan: PlannedActivity) -> String? {
        guard let firstHot = dayHours.first(where: { $0.temperatureC > limit }), firstHot.time < plan.end else { return nil }
        let peak = dayHours
            .filter { $0.time >= firstHot.time && $0.time < plan.end }
            .map(\.temperatureC)
            .max() ?? firstHot.temperatureC
        let hour = calendar.component(.hour, from: firstHot.time)
        let partOfDay = hour < 12 ? "this morning" : hour < 17 ? "this afternoon" : "this evening"
        let room = place.kind == .home ? "your room gets" : "\(place.name) gets"
        return "It reaches \(Self.whole(peak))°C outside \(partOfDay). You've said \(room) too hot above \(Self.whole(limit))°C."
    }

    /// Lin's limits on the trip there. Under 10 minutes outside is a tip.
    private func onTheWayFindings(
        travel: TravelEstimate,
        leaveBy: Date,
        start: Date,
        forecast: ConditionsForecast?,
        preferences: ComfortPreferences
    ) throws -> [Assessed] {
        let minutesOutside = Self.minutesOutside(travel)
        guard minutesOutside > 0, leaveBy < start else { return [] }
        let tripHours = forecast?.conditions(during: DateInterval(start: leaveBy, end: start)) ?? []
        let severity = PlanFinding.Severity.forLimitExceededOnTheWay(minutesOutside: minutesOutside)

        return try ConditionSensitivity.allCases.compactMap { sensitivity in
            guard let exceedance = Self.exceedance(sensitivity, in: tripHours, preferences: preferences) else { return nil }
            let message = severity == .tip
                ? "\(exceedance.label) · \(minutesOutside) min outside\(exceedance.advice)"
                : "\(exceedance.label) on the way (\(minutesOutside) min outside), above your limit \(exceedance.limit)."
            return Assessed(
                finding: try PlanFinding(factor: .conditions, severity: severity, message: message),
                reasonKey: severity == .problem ? sensitivity.rawValue : nil
            )
        }
    }

    /// Walking counts the whole trip, public transport the walk to and from
    /// the stop, driving nothing.
    static func minutesOutside(_ travel: TravelEstimate) -> Int {
        switch travel.mode {
        case .walking: return travel.minutes
        case .publicTransport: return publicTransportMinutesOutside
        case .driving: return 0
        }
    }

    /// The worst hour above Lin's limit for one condition, in her words.
    private struct Exceedance {
        /// e.g. "UV 9", "Air quality Poor".
        let label: String
        /// e.g. "of 8", "(Fair)".
        let limit: String
        /// e.g. ", wear sunscreen"; empty if none.
        let advice: String
        let firstTime: Date
    }

    private static func exceedance(
        _ sensitivity: ConditionSensitivity,
        in hours: [HourlyConditions],
        preferences: ComfortPreferences
    ) -> Exceedance? {
        switch sensitivity {
        case .heat:
            let bad = hours.filter { $0.apparentTemperatureC > preferences.maxApparentTemperatureC }
            guard let first = bad.first, let worst = bad.map(\.apparentTemperatureC).max() else { return nil }
            return Exceedance(label: "Feels like \(whole(worst))°C", limit: "of \(whole(preferences.maxApparentTemperatureC))°C", advice: "", firstTime: first.time)
        case .poorAirQuality:
            let bad = hours.filter { $0.airQuality > preferences.worstAcceptableAirQuality }
            guard let first = bad.first, let worst = bad.map(\.airQuality).max() else { return nil }
            return Exceedance(label: "Air quality \(worst.name)", limit: "(\(preferences.worstAcceptableAirQuality.name))", advice: "", firstTime: first.time)
        case .uv:
            let bad = hours.filter { $0.uvIndex > preferences.maxUVIndex }
            guard let first = bad.first, let worst = bad.map(\.uvIndex).max() else { return nil }
            return Exceedance(label: "UV \(whole(worst))", limit: "of \(whole(preferences.maxUVIndex))", advice: ", wear sunscreen", firstTime: first.time)
        case .wind:
            let bad = hours.filter { $0.windGustsKmh > preferences.maxWindGustsKmh }
            guard let first = bad.first, let worst = bad.map(\.windGustsKmh).max() else { return nil }
            return Exceedance(label: "Wind gusts \(whole(worst)) km/h", limit: "of \(whole(preferences.maxWindGustsKmh)) km/h", advice: "", firstTime: first.time)
        case .rain:
            let bad = hours.filter { $0.precipitationProbability > preferences.maxRainProbability }
            guard let first = bad.first, let worst = bad.map(\.precipitationProbability).max() else { return nil }
            return Exceedance(label: "\(worst)% chance of rain", limit: "of \(preferences.maxRainProbability)%", advice: ", take an umbrella", firstTime: first.time)
        }
    }

    // MARK: Travel, opening hours, crowds

    private func travelFinding(
        _ plan: PlannedActivity,
        travel: TravelEstimate?,
        leaveBy: Date?,
        previous: PlannedActivity?,
        context: Context
    ) throws -> Assessed {
        guard let travel, let leaveBy else {
            return Assessed(
                finding: try PlanFinding(factor: .travel, severity: .tip, message: "Add Home in My Places so DayShift can estimate travel."),
                reasonKey: nil
            )
        }
        guard travel.minutes > 0 else {
            return Assessed(finding: try PlanFinding(factor: .travel, severity: .fine, message: "You're already here."), reasonKey: nil)
        }

        if let previous {
            let conflicts = DaySchedule(date: plan.start, plans: context.dayPlans).conflicts(
                for: plan.interval,
                travelBefore: travel.minutes,
                travelAfter: 0,
                excluding: [plan.id],
                buffer: context.preferences.minimumBufferMinutes
            )
            for case let .notEnoughGap(planID, available, required) in conflicts where planID == previous.id {
                return Assessed(
                    finding: try PlanFinding(
                        factor: .travel,
                        severity: .problem,
                        message: "You need \(required) minutes to get here after \(previous.title), but there are only \(available)."
                    ),
                    reasonKey: PlanFinding.Factor.travel.rawValue
                )
            }
        }

        let message = "\(Self.travelText(travel)) · estimate · Leave by \(TimeText.time(leaveBy, calendar: calendar))"
        return Assessed(finding: try PlanFinding(factor: .travel, severity: .fine, message: message), reasonKey: nil)
    }

    /// e.g. "5 min walk", "12 min by public transport".
    static func travelText(_ travel: TravelEstimate) -> String {
        switch travel.mode {
        case .walking: return "\(travel.minutes) min walk"
        case .publicTransport: return "\(travel.minutes) min by public transport"
        case .driving: return "\(travel.minutes) min drive"
        }
    }

    private func openingHoursFinding(_ plan: PlannedActivity, place: Place) throws -> Assessed {
        if place.isAlwaysOpen {
            let message = place.kind == .home ? "Always available." : "Open 24 hours."
            return Assessed(finding: try PlanFinding(factor: .openingHours, severity: .fine, message: message), reasonKey: nil)
        }
        guard let hours = place.openingHours else {
            return Assessed(finding: try PlanFinding(factor: .openingHours, severity: .tip, message: "Opening hours not confirmed."), reasonKey: nil)
        }
        if hours.isOpen(throughout: plan.interval, calendar: calendar) {
            let message = "Open until \(TimeText.shortTime(minutesAfterMidnight: hours.closesAt))."
            return Assessed(finding: try PlanFinding(factor: .openingHours, severity: .fine, message: message), reasonKey: nil)
        }
        return Assessed(
            finding: try PlanFinding(factor: .openingHours, severity: .problem, message: "\(place.name) is closed for part of this plan."),
            reasonKey: PlanFinding.Factor.openingHours.rawValue
        )
    }

    /// Crowds are estimates, so they are never a problem.
    private func crowdFinding(_ plan: PlannedActivity, place: Place) throws -> Assessed {
        let finding: PlanFinding
        switch place.kind.typicalCrowd(at: plan.start, calendar: calendar) {
        case .quiet:
            finding = try PlanFinding(factor: .crowds, severity: .fine, message: "Usually quiet · estimate")
        case .moderate:
            finding = try PlanFinding(factor: .crowds, severity: .fine, message: "Usually moderately busy · estimate")
        case .busy:
            finding = try PlanFinding(factor: .crowds, severity: .tip, message: "Usually busy · estimate")
        }
        return Assessed(finding: finding, reasonKey: nil)
    }

    /// 33.0 → "33", 32.6 → "33".
    private static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
