import Foundation

/// Why options couldn't be suggested (Section 3.3). Says what went wrong and what to do next.
public enum SuggestAlternativesError: LocalizedError, Equatable {
    case planHasNoFlexibility
    case noViableAlternative
    case forecastUnavailable

    public var errorDescription: String? {
        switch self {
        case .planHasNoFlexibility: return "This plan is fixed, so DayShift can't suggest changes."
        case .noViableAlternative: return "No time or place today keeps this plan within your limits."
        case .forecastUnavailable: return CheckUpcomingPlansError.forecastUnavailable.errorDescription
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .planHasNoFlexibility: return "Edit the plan to allow a different time or place."
        case .noViableAlternative: return "Try another day, or adjust your limits in Settings."
        case .forecastUnavailable: return CheckUpcomingPlansError.forecastUnavailable.recoverySuggestion
        }
    }
}

/// The options for one plan, best first, and how the plan itself scores.
public struct AlternativeSuggestions: Equatable, Sendable {
    /// The plan as it is, on the same 0–100 scale as the options.
    public let currentScore: Int
    /// Up to three, best first.
    public let options: [AlternativePlan]
}

/// Suggests up to three other times or places for a plan (Section 3.3).
/// Every option passes the same checks as 3.2 with no problems.
public struct SuggestAlternativesUseCase {
    static let maximumOptions = 3
    static let stepMinutes = 30

    private let activities: ActivityRepository
    private let places: PlaceRepository
    private let preferences: PreferencesRepository
    private let conditions: ConditionsService
    private let travelTimes: TravelTimeService
    private let calendar: Calendar

    public init(
        activities: ActivityRepository,
        places: PlaceRepository,
        preferences: PreferencesRepository,
        conditions: ConditionsService,
        travelTimes: TravelTimeService,
        calendar: Calendar = .current
    ) {
        self.activities = activities
        self.places = places
        self.preferences = preferences
        self.conditions = conditions
        self.travelTimes = travelTimes
        self.calendar = calendar
    }

    private var assessor: PlanAssessor {
        PlanAssessor(travelTimes: travelTimes, calendar: calendar)
    }

    public func execute(for plan: PlannedActivity, now: Date) async throws -> AlternativeSuggestions {
        guard plan.flexibility.allowsAnyChange else {
            throw SuggestAlternativesError.planHasNoFlexibility
        }
        let preferences = try await self.preferences.load()
        let home = try await places.home()
        let dayPlans = try await activities.plans(on: plan.start)
        let savedPlaces = try await places.allPlaces()
        let activityType = ActivityCatalogue.type(withID: plan.typeID)

        var coordinates: [Coordinate] = []
        for place in [plan.place].compactMap({ $0 }) + savedPlaces + dayPlans.compactMap(\.place)
        where !coordinates.contains(place.coordinate) {
            coordinates.append(place.coordinate)
        }
        let forecasts: [Coordinate: ConditionsForecast]
        do {
            forecasts = try await conditions.forecast(for: coordinates, on: plan.start)
        } catch {
            throw SuggestAlternativesError.forecastUnavailable
        }

        let context = PlanAssessor.Context(
            preferences: preferences,
            home: home,
            dayPlans: dayPlans.filter { $0.id != plan.id } + [plan],
            forecasts: forecasts
        )
        let current = try assessor.assess(plan, context: context)
        let currentProblems = current.findings.filter { $0.finding.severity == .problem }
        let currentScore = score(plan, changeScore: 30, hasKnockOn: false, context: context, activityType: activityType)

        var options: [AlternativePlan] = []
        for candidate in try timeShifts(of: plan, preferences: preferences, now: now) {
            if let option = try evaluate(candidate, original: plan, problems: currentProblems,
                                         changeScore: Self.changeScore(from: plan.start, to: candidate.start),
                                         context: context, activityType: activityType, now: now) {
                options.append(option)
            }
        }
        if plan.flexibility.allowsPlaceChange, let currentPlace = plan.place {
            for place in candidatePlaces(for: plan, currentPlace: currentPlace, savedPlaces: savedPlaces,
                                         problems: currentProblems, activityType: activityType) {
                let candidate = try PlannedActivity(
                    id: plan.id, typeID: plan.typeID, title: plan.title,
                    start: plan.start, durationMinutes: plan.durationMinutes,
                    place: place, mode: plan.mode, flexibility: plan.flexibility, status: plan.status
                )
                if let option = try evaluate(candidate, original: plan, problems: currentProblems,
                                             changeScore: 15, context: context,
                                             activityType: activityType, now: now) {
                    options.append(option)
                }
            }
        }

        guard !options.isEmpty else {
            throw SuggestAlternativesError.noViableAlternative
        }
        let best = options
            .sorted { lhs, rhs in
                lhs.score != rhs.score ? lhs.score > rhs.score : Self.startOf(lhs, plan) < Self.startOf(rhs, plan)
            }
            .prefix(Self.maximumOptions)
        return AlternativeSuggestions(currentScore: currentScore, options: Array(best))
    }

    // MARK: - Candidates

    /// Every 30 minutes inside the movable window and planning hours, not in
    /// the past, same place and duration.
    private func timeShifts(of plan: PlannedActivity, preferences: ComfortPreferences, now: Date) throws -> [PlannedActivity] {
        guard let window = plan.flexibility.movableWindow else { return [] }
        return try startTimes(in: window, durationMinutes: plan.durationMinutes, preferences: preferences, now: now)
            .filter { $0 != plan.start }
            .map { start in
                try PlannedActivity(
                    id: plan.id, typeID: plan.typeID, title: plan.title,
                    start: start, durationMinutes: plan.durationMinutes,
                    place: plan.place, mode: plan.mode, flexibility: plan.flexibility, status: plan.status
                )
            }
    }

    private func startTimes(in window: DateInterval, durationMinutes: Int, preferences: ComfortPreferences, now: Date) -> [Date] {
        var starts: [Date] = []
        var start = window.start
        let duration = TimeInterval(durationMinutes * 60)
        while start.addingTimeInterval(duration) <= window.end {
            let interval = DateInterval(start: start, duration: duration)
            if start >= now, isWithinPlanningHours(interval, preferences: preferences) {
                starts.append(start)
            }
            start = start.addingTimeInterval(TimeInterval(Self.stepMinutes * 60))
        }
        return starts
    }

    /// Saved places that suit the activity, other than the current one:
    /// indoor when the problem is outdoor conditions, cooled when it is heat.
    private func candidatePlaces(
        for plan: PlannedActivity,
        currentPlace: Place,
        savedPlaces: [Place],
        problems: [PlanAssessor.Assessed],
        activityType: ActivityType?
    ) -> [Place] {
        let conditionProblem = problems.contains { $0.finding.factor == .conditions }
        let heatProblem = problems.contains { $0.reasonKey == ConditionSensitivity.heat.rawValue }
        return savedPlaces.filter { place in
            guard place.id != currentPlace.id else { return false }
            if let activityType, !activityType.suitablePlaceKinds.contains(place.kind) { return false }
            if conditionProblem, !currentPlace.isIndoor, !place.isIndoor { return false }
            if heatProblem, !place.isCooled { return false }
            return true
        }
    }

    // MARK: - Evaluating a candidate

    /// An option if the candidate fits the day (with at most one knock-on
    /// change) and its check has no problems; otherwise nil.
    private func evaluate(
        _ candidate: PlannedActivity,
        original: PlannedActivity,
        problems: [PlanAssessor.Assessed],
        changeScore: Int,
        context: PlanAssessor.Context,
        activityType: ActivityType?,
        now: Date
    ) throws -> AlternativePlan? {
        let others = context.dayPlans.filter { $0.id != original.id }
        let blocking = blockingPlans(for: candidate, among: others, context: context)

        var knockOn: PlannedActivity?
        if !blocking.isEmpty {
            guard blocking.count == 1, let blocker = blocking.first,
                  let moved = try knockOnMove(of: blocker, around: candidate, others: others, context: context, now: now)
            else { return nil }
            knockOn = moved
        }

        var candidateContext = context
        candidateContext.dayPlans = others.map { $0.id == knockOn?.id ? knockOn ?? $0 : $0 } + [candidate]
        let assessment = try assessor.assess(candidate, context: candidateContext)
        guard !assessment.findings.contains(where: { $0.finding.severity == .problem }) else { return nil }

        let score = self.score(candidate, changeScore: changeScore, hasKnockOn: knockOn != nil,
                               context: candidateContext, activityType: activityType)
        let adjustment: Adjustment
        if let newPlace = candidate.place, newPlace.id != original.place?.id {
            adjustment = .changePlace(newPlace)
        } else {
            adjustment = .shiftTime(newStart: candidate.start)
        }

        return try AlternativePlan(
            planID: original.id,
            adjustment: adjustment,
            knockOn: knockOn.map { moved in
                KnockOnChange(planID: moved.id, title: moved.title, newStart: moved.start)
            },
            score: score,
            explanation: explanation(for: candidate, original: original, problems: problems,
                                     assessment: assessment, context: candidateContext, activityType: activityType),
            scheduleNote: scheduleNote(for: candidate, knockOn: knockOn, others: others)
        )
    }

    /// The other plans that stop the candidate fitting: overlaps, or not
    /// enough time to get there or to the next plan.
    private func blockingPlans(for candidate: PlannedActivity, among others: [PlannedActivity], context: PlanAssessor.Context) -> [PlannedActivity] {
        let conflicts = DaySchedule(date: candidate.start, plans: others).conflicts(
            for: candidate.interval,
            travelBefore: travelMinutes(before: candidate, among: others, home: context.home, preferences: context.preferences),
            travelAfter: travelMinutes(after: candidate, among: others, home: context.home, preferences: context.preferences),
            excluding: [candidate.id],
            buffer: context.preferences.minimumBufferMinutes
        )
        let ids = Set(conflicts.map { conflict -> UUID in
            switch conflict {
            case let .overlaps(planID), let .notEnoughGap(planID, _, _): return planID
            }
        })
        return others.filter { ids.contains($0.id) }
    }

    /// Moves one blocking plan inside its own window, closest to its own time,
    /// so both plans fit and both pass the check. Fixed or started plans never move.
    private func knockOnMove(
        of blocker: PlannedActivity,
        around candidate: PlannedActivity,
        others: [PlannedActivity],
        context: PlanAssessor.Context,
        now: Date
    ) throws -> PlannedActivity? {
        guard let window = blocker.flexibility.movableWindow, blocker.start > now else { return nil }
        let rest = others.filter { $0.id != blocker.id }
        let starts = startTimes(in: window, durationMinutes: blocker.durationMinutes, preferences: context.preferences, now: now)
            .filter { $0 != blocker.start }
            .sorted { abs($0.timeIntervalSince(blocker.start)) < abs($1.timeIntervalSince(blocker.start)) }

        for start in starts {
            let moved = try PlannedActivity(
                id: blocker.id, typeID: blocker.typeID, title: blocker.title,
                start: start, durationMinutes: blocker.durationMinutes,
                place: blocker.place, mode: blocker.mode, flexibility: blocker.flexibility, status: blocker.status
            )
            guard blockingPlans(for: candidate, among: rest + [moved], context: context).isEmpty,
                  blockingPlans(for: moved, among: rest + [candidate], context: context).isEmpty
            else { continue }

            var movedContext = context
            movedContext.dayPlans = rest + [candidate, moved]
            let assessment = try assessor.assess(moved, context: movedContext)
            if !assessment.findings.contains(where: { $0.finding.severity == .problem }) {
                return moved
            }
        }
        return nil
    }

    private func travelMinutes(before plan: PlannedActivity, among others: [PlannedActivity], home: Place?, preferences: ComfortPreferences) -> Int {
        let previous = others.filter { $0.end <= plan.start }.max { $0.end < $1.end }
        return travelMinutes(from: previous?.place ?? home, to: plan.place, preferences: preferences)
    }

    private func travelMinutes(after plan: PlannedActivity, among others: [PlannedActivity], home: Place?, preferences: ComfortPreferences) -> Int {
        let next = others.filter { $0.start >= plan.end }.min { $0.start < $1.start }
        return travelMinutes(from: plan.place ?? home, to: next?.place, preferences: preferences)
    }

    private func travelMinutes(from origin: Place?, to destination: Place?, preferences: ComfortPreferences) -> Int {
        guard let origin, let destination else { return 0 }
        return travelTimes.travelEstimate(from: origin.coordinate, to: destination.coordinate, mode: preferences.travelMode).minutes
    }

    private func isWithinPlanningHours(_ interval: DateInterval, preferences: ComfortPreferences) -> Bool {
        let startOfDay = calendar.startOfDay(for: interval.start)
        let startMinute = calendar.dateComponents([.minute], from: startOfDay, to: interval.start).minute ?? 0
        let endMinute = calendar.dateComponents([.minute], from: startOfDay, to: interval.end).minute ?? 0
        return startMinute >= preferences.earliestPlanTime && endMinute <= preferences.latestPlanTime
    }

    // MARK: - Scoring (3.3)

    /// 30 for no change, minus 1 for every 30 minutes moved.
    static func changeScore(from original: Date, to new: Date) -> Int {
        let minutes = Int(abs(new.timeIntervalSince(original)) / 60)
        return max(0, 30 - minutes / stepMinutes)
    }

    private func score(
        _ plan: PlannedActivity,
        changeScore: Int,
        hasKnockOn: Bool,
        context: PlanAssessor.Context,
        activityType: ActivityType?
    ) -> Int {
        let conditions = Int((40 * conditionsMargin(plan, context: context, activityType: activityType)).rounded())
        let crowds: Int
        if let place = plan.place {
            switch place.kind.typicalCrowd(at: plan.start, calendar: calendar) {
            case .quiet: crowds = 10
            case .moderate: crowds = 5
            case .busy: crowds = 0
            }
        } else {
            crowds = 10
        }
        return min(100, max(0, conditions + changeScore + (hasKnockOn ? 0 : 20) + crowds))
    }

    /// 0–1: how far the plan's worst hour stays from Lin's limits.
    private func conditionsMargin(_ plan: PlannedActivity, context: PlanAssessor.Context, activityType: ActivityType?) -> Double {
        guard let place = plan.place else { return 1 }
        let forecast = context.forecasts[place.coordinate]
        if place.isIndoor {
            guard !place.isCooled, let limit = place.uncooledHeatLimitC else { return 1 }
            let startOfDay = calendar.startOfDay(for: plan.start)
            let hottest = forecast?.hours
                .filter { $0.time >= startOfDay && $0.time < plan.end }
                .map(\.temperatureC)
                .max()
            return hottest.map { Self.margin(limit: limit, worst: $0) } ?? 0
        }

        let hours = forecast?.conditions(during: plan.interval) ?? []
        guard !hours.isEmpty else { return 0 }
        let preferences = context.preferences
        let sensitivities = activityType?.sensitivities ?? Set(ConditionSensitivity.allCases)
        let margins: [Double] = sensitivities.map { sensitivity in
            switch sensitivity {
            case .heat:
                return Self.margin(limit: preferences.maxApparentTemperatureC, worst: hours.map(\.apparentTemperatureC).max() ?? 0)
            case .poorAirQuality:
                guard let limit = preferences.worstAcceptableAirQuality.pm25UpperBound else { return 1 }
                return Self.margin(limit: limit, worst: hours.map(\.pm25).max() ?? 0)
            case .uv:
                return Self.margin(limit: preferences.maxUVIndex, worst: hours.map(\.uvIndex).max() ?? 0)
            case .wind:
                return Self.margin(limit: preferences.maxWindGustsKmh, worst: hours.map(\.windGustsKmh).max() ?? 0)
            case .rain:
                return Self.margin(limit: Double(preferences.maxRainProbability),
                                   worst: Double(hours.map(\.precipitationProbability).max() ?? 0))
            }
        }
        return margins.min() ?? 1
    }

    /// (limit − worst) / limit, kept between 0 and 1.
    static func margin(limit: Double, worst: Double) -> Double {
        guard limit > 0 else { return worst <= 0 ? 1 : 0 }
        return min(1, max(0, (limit - worst) / limit))
    }

    // MARK: - Wording

    /// Needs attention: what gets better, e.g. "Air quality returns to Good and UV is low."
    /// Looks good: what is different, e.g. "Usually quiet at 7 pm (estimate)."
    private func explanation(
        for candidate: PlannedActivity,
        original: PlannedActivity,
        problems: [PlanAssessor.Assessed],
        assessment: PlanAssessor.Assessment,
        context: PlanAssessor.Context,
        activityType: ActivityType?
    ) -> String {
        guard let place = candidate.place else {
            return "Starts at \(TimeText.time(candidate.start, calendar: calendar))."
        }
        let hours = context.forecasts[place.coordinate]?.conditions(during: candidate.interval) ?? []

        if candidate.place?.id != original.place?.id {
            var sentences: [String] = []
            if !problems.isEmpty || original.place?.isIndoor == false || original.place?.isCooled == false {
                if place.isIndoor && place.isCooled {
                    sentences.append(problems.contains { $0.reasonKey == ConditionSensitivity.heat.rawValue }
                        ? "Air-conditioned, so the heat doesn't matter."
                        : "Indoors and air-conditioned.")
                } else if place.isIndoor {
                    sentences.append("Indoors, so the weather doesn't matter.")
                }
            }
            var details: [String] = []
            if let hours = place.openingHours {
                details.append("Open until \(TimeText.shortTime(minutesAfterMidnight: hours.closesAt))")
            }
            if let travel = assessment.travel, travel.minutes > 0 {
                details.append(PlanAssessor.travelText(travel))
            }
            if !details.isEmpty {
                sentences.append(details.joined(separator: ", ") + ".")
            }
            return sentences.isEmpty ? "At \(place.name) instead of \(original.place?.name ?? "online")." : sentences.joined(separator: " ")
        }

        guard problems.isEmpty else {
            var clauses: [String] = []
            let solved = Set(problems.compactMap(\.reasonKey))
            if solved.contains(ConditionSensitivity.poorAirQuality.rawValue), let worst = hours.map(\.airQuality).max() {
                clauses.append("air quality returns to \(worst.name)")
            }
            if solved.contains(ConditionSensitivity.heat.rawValue), let worst = hours.map(\.apparentTemperatureC).max() {
                clauses.append(place.isIndoor ? "it stays cooler outside" : "it feels like \(Int(worst.rounded()))°C")
            }
            if solved.contains(ConditionSensitivity.uv.rawValue), let worst = hours.map(\.uvIndex).max() {
                clauses.append("UV drops to \(Int(worst.rounded()))")
            }
            if solved.contains(ConditionSensitivity.wind.rawValue), let worst = hours.map(\.windGustsKmh).max() {
                clauses.append("wind gusts ease to \(Int(worst.rounded())) km/h")
            }
            if solved.contains(ConditionSensitivity.rain.rawValue), let worst = hours.map(\.precipitationProbability).max() {
                clauses.append("rain is less likely (\(worst)%)")
            }
            if solved.contains(PlanFinding.Factor.travel.rawValue) {
                clauses.append("there's enough time to get there")
            }
            if solved.contains(PlanFinding.Factor.openingHours.rawValue) {
                clauses.append("\(place.name) is open for the whole plan")
            }
            let uvLow = (hours.map(\.uvIndex).max() ?? 99) <= 2
            if !place.isIndoor, activityType?.sensitivities.contains(.uv) == true,
               !solved.contains(ConditionSensitivity.uv.rawValue), uvLow {
                clauses.append("UV is low")
            }
            return Self.sentence(clauses) ?? "Within your limits at \(TimeText.time(candidate.start, calendar: calendar))."
        }

        var sentences: [String] = []
        let originalCrowd = original.place?.kind.typicalCrowd(at: original.start, calendar: calendar)
        let crowd = place.kind.typicalCrowd(at: candidate.start, calendar: calendar)
        if let originalCrowd, Self.rank(crowd) < Self.rank(originalCrowd) {
            let time = TimeText.shortTime(candidate.start, calendar: calendar)
            sentences.append(crowd == .quiet
                ? "Usually quiet at \(time) (estimate)."
                : "Usually less busy at \(time) (estimate).")
        }
        if sentences.isEmpty {
            sentences.append("Starts at \(TimeText.time(candidate.start, calendar: calendar)) instead of \(TimeText.time(original.start, calendar: calendar)).")
        }
        return sentences.joined(separator: " ")
    }

    /// e.g. "Grocery run moves from 5:30 to 6:30 pm. Your 11 am client call is not affected."
    private func scheduleNote(for candidate: PlannedActivity, knockOn: PlannedActivity?, others: [PlannedActivity]) -> String {
        var sentences: [String] = []
        if let knockOn, let original = others.first(where: { $0.id == knockOn.id }) {
            let times = TimeText.range(original.start, knockOn.start, calendar: calendar)
                .replacingOccurrences(of: "–", with: " to ")
            sentences.append("\(knockOn.title) moves from \(times).")
        } else {
            sentences.append("Nothing else moves.")
        }
        if let fixed = others
            .filter({ !$0.flexibility.allowsAnyChange && $0.id != knockOn?.id })
            .min(by: { $0.start < $1.start }) {
            sentences.append("Your \(TimeText.shortTime(fixed.start, calendar: calendar)) \(fixed.title.lowercased()) is not affected.")
        }
        return sentences.joined(separator: " ")
    }

    /// ["air quality returns to Good", "UV is low"] → "Air quality returns to Good and UV is low."
    static func sentence(_ clauses: [String]) -> String? {
        guard let first = clauses.first else { return nil }
        let joined: String
        switch clauses.count {
        case 1: joined = first
        case 2: joined = "\(clauses[0]) and \(clauses[1])"
        default: joined = clauses.dropLast().joined(separator: ", ") + " and " + clauses[clauses.count - 1]
        }
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }

    private static func rank(_ crowd: CrowdLevel) -> Int {
        switch crowd {
        case .quiet: return 0
        case .moderate: return 1
        case .busy: return 2
        }
    }

    private static func startOf(_ option: AlternativePlan, _ plan: PlannedActivity) -> Date {
        if case let .shiftTime(newStart) = option.adjustment { return newStart }
        return plan.start
    }
}
