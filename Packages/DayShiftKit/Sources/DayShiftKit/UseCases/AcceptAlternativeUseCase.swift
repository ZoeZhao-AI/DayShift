import Foundation

/// Why an option couldn't be used (Section 3.4). Says what went wrong and what to do next.
public enum AcceptAlternativeError: LocalizedError, Equatable {
    /// e.g. reason "Newtown Library closes at 4 pm".
    case noLongerAvailable(reason: String)
    case planAlreadyStarted
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case let .noLongerAvailable(reason): return "This option is no longer possible: \(reason)."
        case .planAlreadyStarted: return "This plan has already started."
        case .saveFailed: return "Your change couldn't be saved."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noLongerAvailable: return "Go back to see updated options."
        case .planAlreadyStarted: return "Plan a new activity instead."
        case .saveFailed: return "Please try again. Your original plan hasn't changed."
        }
    }
}

/// Uses an option for a plan (Section 3.4): re-checks it with the latest
/// forecast, places and schedule, then saves the plan and any knock-on
/// change together, with one record each.
public struct AcceptAlternativeUseCase {
    /// How many days after today a plan is looked for, as on Today's "Coming up".
    static let daysAhead = 7

    private let activities: ActivityRepository
    private let places: PlaceRepository
    private let preferences: PreferencesRepository
    private let conditions: ConditionsService
    private let travelTimes: TravelTimeService
    private let planChecker: PlanChecking
    private let widget: WidgetRefreshing
    private let notifications: NotificationScheduling
    private let calendar: Calendar

    public init(
        activities: ActivityRepository,
        places: PlaceRepository,
        preferences: PreferencesRepository,
        conditions: ConditionsService,
        travelTimes: TravelTimeService,
        planChecker: PlanChecking,
        widget: WidgetRefreshing,
        notifications: NotificationScheduling,
        calendar: Calendar = .current
    ) {
        self.activities = activities
        self.places = places
        self.preferences = preferences
        self.conditions = conditions
        self.travelTimes = travelTimes
        self.planChecker = planChecker
        self.widget = widget
        self.notifications = notifications
        self.calendar = calendar
    }

    private var assessor: PlanAssessor {
        PlanAssessor(travelTimes: travelTimes, calendar: calendar)
    }

    private var fit: ScheduleFit {
        ScheduleFit(travelTimes: travelTimes, calendar: calendar)
    }

    /// Saves the option and returns the changed plan. Afterwards it refreshes
    /// the widget, removes the changed plans' notifications, and checks the
    /// rest of the day again, which also reschedules leave reminders.
    @discardableResult
    public func execute(_ option: AlternativePlan, now: Date) async throws -> PlannedActivity {
        let (plan, dayPlans) = try await findPlan(option.planID, now: now)
        guard plan.start > now else {
            throw AcceptAlternativeError.planAlreadyStarted
        }

        let preferences = try await self.preferences.load()
        let home = try await places.home()
        let savedPlaces = try await places.allPlaces()

        // The option as it would be now, with the latest saved places.
        let changed = try changedPlan(plan, for: option.adjustment, savedPlaces: savedPlaces)
        var moved: (original: PlannedActivity, moved: PlannedActivity)?
        if let knockOn = option.knockOn {
            guard let other = dayPlans.first(where: { $0.id == knockOn.planID }) else {
                throw AcceptAlternativeError.noLongerAvailable(reason: "\(knockOn.title) is no longer planned")
            }
            guard other.start > now else {
                throw AcceptAlternativeError.noLongerAvailable(reason: "\(other.title) has already started")
            }
            moved = (other, try Self.replacing(other, start: knockOn.newStart, place: other.place))
        }

        let others = dayPlans.filter { $0.id != plan.id && $0.id != moved?.original.id }
        for candidate in [changed] + [moved?.moved].compactMap({ $0 }) {
            guard fit.isWithinPlanningHours(candidate.interval, preferences: preferences) else {
                throw AcceptAlternativeError.noLongerAvailable(reason: "\(candidate.title) would be outside your planning hours")
            }
            let rest = others + [changed, moved?.moved].compactMap { $0 }.filter { $0.id != candidate.id }
            if let conflict = fit.conflicts(for: candidate, among: rest, home: home, preferences: preferences).first {
                throw AcceptAlternativeError.noLongerAvailable(reason: Self.reason(for: conflict, among: rest))
            }
        }

        // Re-check with the latest forecast.
        let assessedPlaces = [plan.place, changed.place, moved?.moved.place].compactMap { $0 }
        var coordinates: [Coordinate] = []
        for place in assessedPlaces where !coordinates.contains(place.coordinate) {
            coordinates.append(place.coordinate)
        }
        let forecasts: [Coordinate: ConditionsForecast]
        do {
            forecasts = coordinates.isEmpty ? [:] : try await conditions.forecast(for: coordinates, on: plan.start)
        } catch {
            throw AcceptAlternativeError.noLongerAvailable(reason: "weather and air quality can't be checked right now")
        }
        let newContext = PlanAssessor.Context(
            preferences: preferences,
            home: home,
            dayPlans: others + [changed] + [moved?.moved].compactMap { $0 },
            forecasts: forecasts
        )
        for candidate in [changed] + [moved?.moved].compactMap({ $0 }) {
            let assessment = try assessor.assess(candidate, context: newContext)
            if let problem = assessment.findings.first(where: { $0.finding.severity == .problem }) {
                throw AcceptAlternativeError.noLongerAvailable(reason: reason(for: problem, plan: candidate))
            }
        }

        // Why the plan changed, from its problems before the change.
        let oldContext = PlanAssessor.Context(preferences: preferences, home: home, dayPlans: dayPlans, forecasts: forecasts)
        let originalProblems = try assessor.assess(plan, context: oldContext).findings
            .filter { $0.finding.severity == .problem }
            .compactMap(\.reasonKey)

        var changedPlans = [try Self.adjusted(changed)]
        var records = [Self.record(for: plan, changedTo: changed, reason: Self.reasonWord(for: originalProblems), at: now)]
        if let moved {
            changedPlans.append(try Self.adjusted(moved.moved))
            records.append(Self.record(for: moved.original, changedTo: moved.moved, reason: "Made room for \(plan.title)", at: now))
        }

        do {
            try await activities.applyAdjustment(changedPlans: changedPlans, records: records)
        } catch {
            throw AcceptAlternativeError.saveFailed
        }

        for changedPlan in changedPlans {
            await notifications.removeNotifications(forPlan: changedPlan.id)
        }
        // Re-check the rest of the day; a failed check doesn't undo the change.
        if let checkable = try? await activities.checkablePlans(on: changed.start, now: now) {
            for plan in checkable {
                _ = try? await planChecker.checkPlan(plan, now: now)
            }
        }
        widget.reload()
        return changedPlans[0]
    }

    // MARK: - Finding the plan

    /// The plan and the other plans on its day. Looks at today and the days
    /// shown under "Coming up".
    private func findPlan(_ id: UUID, now: Date) async throws -> (PlannedActivity, [PlannedActivity]) {
        let today = calendar.startOfDay(for: now)
        for offset in 0...Self.daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayPlans = try await activities.plans(on: day)
            if let plan = dayPlans.first(where: { $0.id == id }) {
                return (plan, dayPlans)
            }
        }
        throw AcceptAlternativeError.noLongerAvailable(reason: "the plan no longer exists")
    }

    // MARK: - Building the change

    private func changedPlan(_ plan: PlannedActivity, for adjustment: Adjustment, savedPlaces: [Place]) throws -> PlannedActivity {
        switch adjustment {
        case let .shiftTime(newStart):
            let place = plan.place.flatMap { current in savedPlaces.first { $0.id == current.id } } ?? plan.place
            return try Self.replacing(plan, start: newStart, place: place)
        case let .changePlace(optionPlace):
            guard let latest = savedPlaces.first(where: { $0.id == optionPlace.id }) else {
                throw AcceptAlternativeError.noLongerAvailable(reason: "\(optionPlace.name) is no longer in My Places")
            }
            return try Self.replacing(plan, start: plan.start, place: latest)
        }
    }

    /// The same plan at another time or place, keeping its duration.
    private static func replacing(_ plan: PlannedActivity, start: Date, place: Place?) throws -> PlannedActivity {
        do {
            return try PlannedActivity(
                id: plan.id, typeID: plan.typeID, title: plan.title,
                start: start, durationMinutes: plan.durationMinutes,
                place: place, mode: plan.mode, flexibility: plan.flexibility, status: plan.status
            )
        } catch {
            throw AcceptAlternativeError.noLongerAvailable(reason: "\(plan.title) no longer fits the times it can move between")
        }
    }

    private static func adjusted(_ plan: PlannedActivity) throws -> PlannedActivity {
        try PlannedActivity(
            id: plan.id, typeID: plan.typeID, title: plan.title,
            start: plan.start, durationMinutes: plan.durationMinutes,
            place: plan.place, mode: plan.mode, flexibility: plan.flexibility, status: .adjusted
        )
    }

    private static func record(for original: PlannedActivity, changedTo changed: PlannedActivity, reason: String, at now: Date) -> AdjustmentRecord {
        AdjustmentRecord(
            planID: original.id,
            kind: changed.place?.id != original.place?.id ? .changePlace : .shiftTime,
            previousStart: original.start,
            newStart: changed.start,
            previousPlaceName: original.place?.name,
            newPlaceName: changed.place?.name,
            reason: reason,
            acceptedAt: now
        )
    }

    // MARK: - Wording

    /// One word for History, e.g. "Smoke"; "Your choice" if the plan looked good.
    static func reasonWord(for reasonKeys: [String]) -> String {
        guard let key = reasonKeys.first else { return "Your choice" }
        switch key {
        case ConditionSensitivity.poorAirQuality.rawValue: return "Smoke"
        case ConditionSensitivity.heat.rawValue: return "Heat"
        case ConditionSensitivity.uv.rawValue: return "UV"
        case ConditionSensitivity.wind.rawValue: return "Wind"
        case ConditionSensitivity.rain.rawValue: return "Rain"
        case PlanFinding.Factor.travel.rawValue: return "Travel time"
        case PlanFinding.Factor.openingHours.rawValue: return "Opening hours"
        default: return "Your choice"
        }
    }

    /// e.g. "Newtown Library closes at 4 pm", "smoke is now forecast at that time".
    private func reason(for problem: PlanAssessor.Assessed, plan: PlannedActivity) -> String {
        switch problem.reasonKey {
        case PlanFinding.Factor.openingHours.rawValue:
            if let place = plan.place, let hours = place.openingHours {
                let weekday = calendar.component(.weekday, from: plan.start)
                return hours.closedWeekdays.contains(weekday)
                    ? "\(place.name) is closed that day"
                    : "\(place.name) closes at \(TimeText.shortTime(minutesAfterMidnight: hours.closesAt))"
            }
            return "\(plan.place?.name ?? "the place") is closed for part of it"
        case ConditionSensitivity.poorAirQuality.rawValue: return "smoke is now forecast at that time"
        case ConditionSensitivity.heat.rawValue: return "it's now forecast to be too hot"
        case ConditionSensitivity.uv.rawValue: return "UV is now above your limit"
        case ConditionSensitivity.wind.rawValue: return "wind gusts are now above your limit"
        case ConditionSensitivity.rain.rawValue: return "rain is now likely"
        case PlanFinding.Factor.travel.rawValue: return "there isn't enough time to get there"
        default: return "it no longer passes the check"
        }
    }

    private static func reason(for conflict: ScheduleConflict, among plans: [PlannedActivity]) -> String {
        let title = plans.first { $0.id == conflict.planID }?.title ?? "another plan"
        switch conflict {
        case .overlaps: return "it overlaps with \(title)"
        case .notEnoughGap: return "there isn't enough time between it and \(title)"
        }
    }
}
