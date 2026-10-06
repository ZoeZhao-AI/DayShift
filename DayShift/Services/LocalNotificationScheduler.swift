import DayShiftKit
import Foundation
import os
import UserNotifications

/// DayShift's local notifications (Section 6.3) through UNUserNotificationCenter.
/// Both situations use the `upcomingPlan` category, so the Notification
/// Content Extension shows them; the payload in `userInfo` carries
/// everything the extension needs.
final class LocalNotificationScheduler: NotificationScheduling {
    private static let logger = Logger(subsystem: "com.utsstudent.zhaoziying.DayShift", category: "Notifications")

    private let center: UNUserNotificationCenter
    private let activities: ActivityRepository
    private let preferences: PreferencesRepository
    private let conditions: ConditionsService
    private let suggestAlternatives: SuggestAlternativesUseCase
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        activities: ActivityRepository,
        preferences: PreferencesRepository,
        conditions: ConditionsService,
        suggestAlternatives: SuggestAlternativesUseCase,
        calendar: Calendar
    ) {
        self.center = center
        self.activities = activities
        self.preferences = preferences
        self.conditions = conditions
        self.suggestAlternatives = suggestAlternatives
        self.calendar = calendar
    }

    /// Registers `upcomingPlan` with its actions; call once at launch.
    /// The extension shows only "Got it" for a leave reminder.
    static func registerCategory(on center: UNUserNotificationCenter = .current()) {
        let category = UNNotificationCategory(
            identifier: NotificationIdentifier.category,
            actions: NotificationAction.allCases.map(Self.unAction),
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    nonisolated static func unAction(_ action: NotificationAction) -> UNNotificationAction {
        UNNotificationAction(identifier: action.rawValue, title: action.title, options: action.opensApp ? [.foreground] : [])
    }

    // MARK: - NotificationScheduling

    /// "Leave in 10 min for Focus work" / "Newtown Library · 12 min by public
    /// transport. Press and hold for details.", at `fireAt`.
    func scheduleLeaveReminder(_ reminder: LeaveReminder) async throws {
        let reminderMinutes = Int((reminder.leaveBy.timeIntervalSince(reminder.fireAt) / 60).rounded())
        let planStart = reminder.leaveBy.addingTimeInterval(TimeInterval(reminder.travel.minutes * 60))
        let payload = NotificationPayload(
            planID: reminder.planID,
            situation: .leaveReminder,
            planTitle: reminder.planTitle,
            planStart: planStart,
            placeName: reminder.placeName,
            leaveBy: reminder.leaveBy,
            travel: reminder.travel,
            findings: reminder.findings,
            onTheWay: await onTheWay(planID: reminder.planID, leaveBy: reminder.leaveBy, start: planStart),
            chart: nil,
            topOption: nil
        )

        let content = UNMutableNotificationContent()
        content.title = "Leave in \(reminderMinutes) min for \(reminder.planTitle)"
        content.body = "\(reminder.placeName) · \(reminder.travel.text). Press and hold for details."
        content.sound = .default
        content.categoryIdentifier = NotificationIdentifier.category
        content.threadIdentifier = reminder.planID.uuidString
        content.userInfo = try payload.userInfo()

        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        try await center.add(UNNotificationRequest(
            identifier: NotificationIdentifier.leaveReminder(planID: reminder.planID),
            content: content,
            trigger: trigger
        ))
    }

    /// "Your 7:00 am run is affected" / "Smoke until 10 am. Press and hold to
    /// see a better option.", straight away, with the chart and the top option.
    func schedulePlanAffectedAlert(_ alert: PlanAffectedAlert) async throws {
        let now = Date()
        let plan = await savedPlan(alert.planID, near: alert.planStart)
        let chart = await problemChart(for: plan, findings: alert.findings, now: now)
        let topOption = await bestOption(for: plan, now: now)

        let payload = NotificationPayload(
            planID: alert.planID,
            situation: .planAffected,
            planTitle: alert.planTitle,
            planStart: alert.planStart,
            placeName: plan?.place?.name,
            leaveBy: nil,
            travel: nil,
            findings: alert.findings,
            onTheWay: nil,
            chart: chart,
            topOption: topOption
        )

        let content = UNMutableNotificationContent()
        content.title = "Your \(TimeText.time(alert.planStart, calendar: calendar)) \(alert.planTitle.lowercased()) is affected"
        content.body = "\(Self.firstSentence(of: alert.reason)) "
            + (topOption == nil ? "Press and hold for details." : "Press and hold to see a better option.")
        content.sound = .default
        content.categoryIdentifier = NotificationIdentifier.category
        content.threadIdentifier = alert.planID.uuidString
        content.userInfo = try payload.userInfo()

        // nil trigger: deliver now.
        try await center.add(UNNotificationRequest(
            identifier: NotificationIdentifier.planAffected(planID: alert.planID),
            content: content,
            trigger: nil
        ))
    }

    func removeNotifications(forPlan planID: UUID) async {
        let identifiers = [
            NotificationIdentifier.leaveReminder(planID: planID),
            NotificationIdentifier.planAffected(planID: planID)
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Payload details

    /// The saved plan, looked up on its day.
    private func savedPlan(_ id: UUID, near date: Date) async -> PlannedActivity? {
        try? await activities.plans(on: date).first { $0.id == id }
    }

    /// The worst hour between leaving and arriving, with Lin's limits.
    /// nil if the plan or forecast can't be read; the reminder still goes out.
    private func onTheWay(planID: UUID, leaveBy: Date, start: Date) async -> OnTheWayConditions? {
        guard leaveBy < start,
              let place = await savedPlan(planID, near: start)?.place,
              let preferences = try? await preferences.load(),
              let forecast = try? await conditions.forecast(for: [place.coordinate], on: start)[place.coordinate]
        else { return nil }
        let hours = forecast.conditions(during: DateInterval(start: leaveBy, end: start))
        guard let air = hours.map(\.airQuality).max() else { return nil }
        return OnTheWayConditions(
            feelsLikeC: hours.map(\.apparentTemperatureC).max() ?? 0,
            uvIndex: hours.map(\.uvIndex).max() ?? 0,
            rainChance: hours.map(\.precipitationProbability).max() ?? 0,
            airQuality: air,
            maxFeelsLikeC: preferences.maxApparentTemperatureC,
            maxUVIndex: preferences.maxUVIndex,
            maxRainChance: preferences.maxRainProbability,
            worstAcceptableAirQuality: preferences.worstAcceptableAirQuality
        )
    }

    /// The same chart as Plan Detail, from DayShiftKit.
    private func problemChart(for plan: PlannedActivity?, findings: [PlanFinding], now: Date) async -> ConditionChartData? {
        guard let plan, let place = plan.place,
              let preferences = try? await preferences.load(),
              let forecast = try? await conditions.forecast(for: [place.coordinate], on: plan.start)[place.coordinate]
        else { return nil }
        let check = PlanCheck(planID: plan.id, checkedAt: now, leaveBy: nil, travel: nil, findings: findings)
        return ConditionChartData.problemChart(
            for: plan, check: check, forecast: forecast, preferences: preferences, calendar: calendar
        )
    }

    /// The top option from SuggestAlternativesUseCase, or nil if there is none.
    private func bestOption(for plan: PlannedActivity?, now: Date) async -> OptionSummary? {
        guard let plan else { return nil }
        do {
            guard let best = try await suggestAlternatives.execute(for: plan, now: now).options.first else { return nil }
            return OptionSummary(
                title: best.title(for: plan, calendar: calendar),
                explanation: best.explanation,
                scheduleNote: best.scheduleNote
            )
        } catch {
            Self.logger.info("No option for the alert: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// "Smoke until 10 am. Air quality Poor, …" → "Smoke until 10 am."
    static func firstSentence(of text: String) -> String {
        guard let end = text.range(of: ". ") else { return text }
        return String(text[..<end.lowerBound]) + "."
    }
}
