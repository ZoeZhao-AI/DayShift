import DayShiftKit
import Foundation
import Observation

/// One plan with its four check rows and, when the conditions are a problem,
/// a chart of that condition against Lin's limit (Section 7.3, PlanDetail).
/// Reads the saved check; deleting goes through ActivityRepository (7.3).
@MainActor
@Observable
final class PlanDetailViewModel {
    struct CheckRow: Identifiable {
        struct Line: Hashable {
            let text: String
            let isTip: Bool
        }

        let id: PlanFinding.Factor
        let title: String
        let symbolName: String
        /// The worst finding in this row.
        let severity: PlanFinding.Severity
        let lines: [Line]
    }

    struct ChartPoint: Identifiable {
        let time: Date
        let value: Double
        var id: Date { time }
    }

    /// The problem condition by the hour, with Lin's limit (7.4).
    struct ConditionChart {
        /// Axis title, e.g. "PM2.5 (µg/m³)".
        let valueName: String
        let points: [ChartPoint]
        let limit: Double
        /// e.g. "Your limit (Fair)".
        let limitLabel: String
        /// e.g. "Air quality at Enmore Park · shaded where it's worse than your limit".
        let caption: String
        /// Shown as "Now" when it falls inside the chart.
        let now: Date?
    }

    private(set) var plan: PlannedActivity
    private(set) var status: PlanDisplayStatus
    private(set) var rows: [CheckRow] = []
    /// Explains why there are no check rows, e.g. for a plan that has started.
    private(set) var note: String?
    private(set) var checkedText: String?
    private(set) var chart: ConditionChart?
    private(set) var error: ErrorMessage?
    private var now: Date

    private let activities: ActivityRepository
    private let preferences: PreferencesRepository
    private let conditions: ConditionsService
    private let widget: WidgetRefreshing
    private let notifications: NotificationScheduling
    private let calendar: Calendar

    init(
        plan: PlannedActivity,
        activities: ActivityRepository,
        preferences: PreferencesRepository,
        conditions: ConditionsService,
        widget: WidgetRefreshing,
        notifications: NotificationScheduling,
        calendar: Calendar,
        now: Date = Date()
    ) {
        self.plan = plan
        self.activities = activities
        self.preferences = preferences
        self.conditions = conditions
        self.widget = widget
        self.notifications = notifications
        self.calendar = calendar
        self.now = now
        status = PlanDisplayStatus(plan: plan, check: nil, now: now, calendar: calendar)
    }

    /// e.g. "7:00 to 7:45 am".
    var timeText: String {
        TimeText.range(plan.start, plan.end, calendar: calendar).replacingOccurrences(of: "–", with: " to ")
    }

    var placeText: String {
        plan.place?.name ?? "Online"
    }

    /// A plan that has started can't be changed (3.4).
    var canEdit: Bool {
        plan.start > now
    }

    /// "See better options" when the plan needs attention, "Find other options"
    /// otherwise; nil for a fixed plan or one that has started (7.4).
    var optionsButtonTitle: String? {
        guard plan.flexibility.allowsAnyChange, plan.start > now else { return nil }
        return status == .needsAttention ? "See better options" : "Find other options"
    }

    func load(now: Date = Date()) async {
        self.now = now
        do {
            if let latest = try await activities.plans(on: plan.start).first(where: { $0.id == plan.id }) {
                plan = latest
            }
            let savedCheck = try await activities.check(for: plan.id)
            status = PlanDisplayStatus(plan: plan, check: savedCheck, now: now, calendar: calendar)
            let shownCheck = PlanDisplayStatus.shownCheck(of: plan, check: savedCheck, now: now, calendar: calendar)
            rows = shownCheck.map(Self.rows(from:)) ?? []
            checkedText = shownCheck.map { "Checked \(TimeText.time($0.checkedAt, calendar: calendar))" }
            note = Self.note(for: status)
            error = nil
            chart = await makeChart(for: shownCheck)
        } catch {
            self.error = ErrorMessage(error)
        }
    }

    /// After "Edit plan" saves, show the edited plan (its day may have changed).
    func replace(with editedPlan: PlannedActivity) {
        plan = editedPlan
    }

    /// Deletes the plan, removes its notifications (6.3) and refreshes the widget (6.2).
    /// Returns true when the plan is deleted.
    func delete() async -> Bool {
        do {
            try await activities.delete(id: plan.id)
            await notifications.removeNotifications(forPlan: plan.id)
            widget.reload()
            return true
        } catch {
            self.error = ErrorMessage(error)
            return false
        }
    }

    // MARK: Rows

    private static let rowOrder: [(factor: PlanFinding.Factor, title: String, symbolName: String)] = [
        (.conditions, "Conditions", "cloud.sun"),
        (.travel, "Travel", "figure.walk"),
        (.openingHours, "Opening hours", "clock"),
        (.crowds, "Crowds", "person.3")
    ]

    private static func rows(from check: PlanCheck) -> [CheckRow] {
        rowOrder.compactMap { factor, title, symbolName in
            let findings = check.findings.filter { $0.factor == factor }
            guard !findings.isEmpty else { return nil }
            let severity: PlanFinding.Severity = findings.contains { $0.severity == .problem } ? .problem
                : findings.contains { $0.severity == .tip } ? .tip
                : .fine
            return CheckRow(
                id: factor,
                title: title,
                symbolName: symbolName,
                severity: severity,
                lines: findings.map { CheckRow.Line(text: $0.message, isTip: $0.severity == .tip) }
            )
        }
    }

    private static func note(for status: PlanDisplayStatus) -> String? {
        switch status {
        case .notCheckedYet: return "DayShift hasn't checked this plan yet. It checks your plans when you open the app."
        case .inProgress: return "This plan has started, so DayShift no longer checks it."
        case .done: return "This plan has finished."
        case .checkedOnTheDay: return "DayShift checks this plan on the day. You can change it any time before then."
        case .looksGood, .needsAttention: return nil
        }
    }

    // MARK: Chart

    /// A chart only when a condition at the place is a problem. A trip-only
    /// problem, or no forecast, shows no chart.
    private func makeChart(for check: PlanCheck?) async -> ConditionChart? {
        guard let check, let place = plan.place,
              check.findings.contains(where: { $0.factor == .conditions && $0.severity == .problem })
        else { return nil }
        guard let forecast = try? await conditions.forecast(for: [place.coordinate], on: plan.start)[place.coordinate]
        else { return nil }
        let preferences = (try? await self.preferences.load()) ?? .default

        let range = chartRange()
        let hours = forecast.hours.filter { $0.time >= range.start && $0.time < range.end }
        guard !hours.isEmpty else { return nil }
        let shownNow = range.contains(now) ? now : nil

        if place.isIndoor {
            guard !place.isCooled, let limit = place.uncooledHeatLimitC else { return nil }
            return ConditionChart(
                valueName: "Outside (°C)",
                points: hours.map { ChartPoint(time: $0.time, value: $0.temperatureC) },
                limit: limit,
                limitLabel: "Too hot above \(Int(limit.rounded()))°C",
                caption: "Temperature outside \(place.name) · shaded where it's above your limit",
                now: shownNow
            )
        }

        let planHours = forecast.conditions(during: plan.interval)
        let sensitivities = ActivityCatalogue.type(withID: plan.typeID)?.sensitivities
            ?? Set(ConditionSensitivity.allCases)
        for sensitivity in ConditionSensitivity.allCases where sensitivities.contains(sensitivity) {
            guard let measure = Self.measure(sensitivity, preferences: preferences),
                  planHours.contains(where: { measure.value($0) > measure.limit })
            else { continue }
            return ConditionChart(
                valueName: measure.valueName,
                points: hours.map { ChartPoint(time: $0.time, value: measure.value($0)) },
                limit: measure.limit,
                limitLabel: measure.limitLabel,
                caption: "\(measure.name) at \(place.name) · shaded where it's worse than your limit",
                now: shownNow
            )
        }
        return nil
    }

    /// From an hour before the plan to an hour after it, at least 6 hours wide,
    /// so it shows when the problem ends.
    private func chartRange() -> DateInterval {
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

/// Lets Today push Plan Detail and present it as navigation state.
extension PlanDetailViewModel: Hashable {
    nonisolated static func == (lhs: PlanDetailViewModel, rhs: PlanDetailViewModel) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
