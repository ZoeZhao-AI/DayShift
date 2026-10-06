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
    /// problem, or no forecast, shows no chart. The chart itself comes from
    /// DayShiftKit, shared with plan-affected notifications.
    private func makeChart(for check: PlanCheck?) async -> ConditionChart? {
        // Only ask for the forecast when there is a problem to chart.
        guard let check, let place = plan.place,
              check.findings.contains(where: { $0.factor == .conditions && $0.severity == .problem }),
              let forecast = try? await conditions.forecast(for: [place.coordinate], on: plan.start)[place.coordinate]
        else { return nil }
        let preferences = (try? await self.preferences.load()) ?? .default
        guard let data = ConditionChartData.problemChart(
            for: plan, check: check, forecast: forecast, preferences: preferences, calendar: calendar
        ) else { return nil }

        let range = ConditionChartData.chartRange(for: plan, calendar: calendar)
        return ConditionChart(
            valueName: data.valueName,
            points: data.points.map { ChartPoint(time: $0.time, value: $0.value) },
            limit: data.limit,
            limitLabel: data.limitLabel,
            caption: place.isIndoor
                ? "\(data.conditionName) \(place.name) · shaded where it's above your limit"
                : "\(data.conditionName) at \(place.name) · shaded where it's worse than your limit",
            now: range.contains(now) ? now : nil
        )
    }
}

/// Lets Today push Plan Detail and present it as navigation state.
extension PlanDetailViewModel: Hashable {
    nonisolated static func == (lhs: PlanDetailViewModel, rhs: PlanDetailViewModel) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
