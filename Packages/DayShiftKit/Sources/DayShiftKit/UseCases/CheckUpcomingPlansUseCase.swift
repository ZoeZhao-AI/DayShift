import Foundation

/// Why the plans couldn't be checked (Section 3.2). Says what went wrong and what to do next.
public enum CheckUpcomingPlansError: LocalizedError, Equatable {
    case forecastUnavailable

    public var errorDescription: String? {
        "Weather and air quality aren't available right now."
    }

    public var recoverySuggestion: String? {
        "Your plans are still saved. DayShift will check again when you next open the app."
    }
}

/// Checks today's plans that haven't started against conditions, travel,
/// opening hours and crowds (Section 3.2).
public struct CheckUpcomingPlansUseCase: PlanChecking {
    /// Plan-affected alerts are only sent for plans starting later than this.
    static let alertLeadMinutes = 15

    private let activities: ActivityRepository
    private let places: PlaceRepository
    private let preferences: PreferencesRepository
    private let conditions: ConditionsService
    private let travelTimes: TravelTimeService
    private let widget: WidgetRefreshing
    private let notifications: NotificationScheduling
    private let calendar: Calendar

    public init(
        activities: ActivityRepository,
        places: PlaceRepository,
        preferences: PreferencesRepository,
        conditions: ConditionsService,
        travelTimes: TravelTimeService,
        widget: WidgetRefreshing,
        notifications: NotificationScheduling,
        calendar: Calendar = .current
    ) {
        self.activities = activities
        self.places = places
        self.preferences = preferences
        self.conditions = conditions
        self.travelTimes = travelTimes
        self.widget = widget
        self.notifications = notifications
        self.calendar = calendar
    }

    /// Checks and saves every plan today that hasn't started, alerts Lin about
    /// new problems, keeps leave reminders in sync, then refreshes the widget.
    /// - Throws: `CheckUpcomingPlansError.forecastUnavailable` if conditions
    ///   can't be fetched; nothing is saved then.
    public func execute(now: Date) async throws -> [PlanCheck] {
        let plans = try await activities.checkablePlans(on: now, now: now)
        let context = try await makeContext(for: plans, day: now)
        var checks: [PlanCheck] = []
        do {
            for plan in plans {
                checks.append(try await process(plan, context: context, now: now))
            }
        } catch {
            // Checks saved before the failure are in the store; show them.
            if !checks.isEmpty {
                widget.reload()
            }
            throw error
        }
        widget.reload()
        return checks
    }

    /// Checks and saves one plan, e.g. right after PlanActivityUseCase saves it.
    public func checkPlan(_ plan: PlannedActivity, now: Date) async throws -> PlanCheck {
        let context = try await makeContext(for: [plan], day: plan.start)
        return try await process(plan, context: context, now: now)
    }

    private var assessor: PlanAssessor {
        PlanAssessor(travelTimes: travelTimes, calendar: calendar)
    }

    // MARK: - Context

    private func makeContext(for plans: [PlannedActivity], day: Date) async throws -> PlanAssessor.Context {
        let preferences = try await self.preferences.load()
        let home = try await places.home()
        let dayPlans = try await activities.plans(on: day)

        var coordinates: [Coordinate] = []
        for place in plans.compactMap(\.place) where !coordinates.contains(place.coordinate) {
            coordinates.append(place.coordinate)
        }
        var forecasts: [Coordinate: ConditionsForecast] = [:]
        if !coordinates.isEmpty {
            do {
                forecasts = try await conditions.forecast(for: coordinates, on: day)
            } catch {
                throw CheckUpcomingPlansError.forecastUnavailable
            }
        }
        return PlanAssessor.Context(preferences: preferences, home: home, dayPlans: dayPlans, forecasts: forecasts)
    }

    // MARK: - Processing

    private func process(_ plan: PlannedActivity, context: PlanAssessor.Context, now: Date) async throws -> PlanCheck {
        let assessment = try assessor.assess(plan, context: context)
        let check = PlanCheck(
            planID: plan.id,
            checkedAt: now,
            leaveBy: assessment.leaveBy,
            travel: assessment.travel,
            findings: assessment.findings.map(\.finding)
        )
        try await activities.saveCheck(check)
        await alertNewProblems(of: plan, assessment: assessment, now: now)
        await scheduleLeaveReminder(for: plan, check: check, preferences: context.preferences, now: now)
        return check
    }

    /// One alert per plan for problems Lin hasn't been alerted about yet, only
    /// for plans today starting more than 15 minutes from now. A plan on a
    /// later day is alerted on its day, so its reasons aren't marked early.
    private func alertNewProblems(of plan: PlannedActivity, assessment: PlanAssessor.Assessment, now: Date) async {
        let problems = assessment.findings.filter { $0.finding.severity == .problem && $0.reasonKey != nil }
        guard !problems.isEmpty,
              calendar.isDate(plan.start, inSameDayAs: now),
              plan.start.timeIntervalSince(now) > TimeInterval(Self.alertLeadMinutes * 60),
              let notified = try? await activities.notifiedReasonKeys(planID: plan.id)
        else { return }

        let newProblems = problems.filter { !notified.contains($0.reasonKey ?? "") }
        guard let firstNew = newProblems.first else { return }
        let newKeys = Set(newProblems.compactMap(\.reasonKey))
        do {
            try await notifications.schedulePlanAffectedAlert(PlanAffectedAlert(
                planID: plan.id,
                planTitle: plan.title,
                planStart: plan.start,
                reason: firstNew.finding.message,
                reasonKeys: newKeys,
                findings: assessment.findings.map(\.finding)
            ))
            try await activities.markNotified(planID: plan.id, reasonKeys: newKeys)
        } catch {
            // Not alerted, so not marked; the next check tries again.
        }
    }

    /// Reschedules the leave reminder with the latest travel time.
    private func scheduleLeaveReminder(for plan: PlannedActivity, check: PlanCheck, preferences: ComfortPreferences, now: Date) async {
        guard let place = plan.place, let travel = check.travel, travel.minutes > 0, let leaveBy = check.leaveBy else { return }
        let fireAt = leaveBy.addingTimeInterval(-TimeInterval(preferences.leaveReminderMinutes * 60))
        guard fireAt > now else { return }
        try? await notifications.scheduleLeaveReminder(LeaveReminder(
            planID: plan.id,
            planTitle: plan.title,
            placeName: place.name,
            travel: travel,
            leaveBy: leaveBy,
            fireAt: fireAt,
            findings: check.findings
        ))
    }

}
