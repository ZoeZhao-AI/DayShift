import Foundation
import Testing
@testable import DayShiftKit

struct NotificationPayloadTests {
    @Test("A leave reminder payload reads back the same")
    func leaveReminderReadsBack() throws {
        let day = try LinsThursday()
        // LeaveExpanded: Focus work at Newtown Library, 12 min by bus, UV 9 on the way.
        let payload = NotificationPayload(
            planID: day.focusWork.id,
            situation: .leaveReminder,
            planTitle: "Focus work",
            planStart: day.time(13),
            placeName: "Newtown Library",
            leaveBy: day.time(12, 35),
            travel: TravelEstimate(minutes: 12, mode: .publicTransport),
            findings: [
                try PlanFinding(factor: .conditions, severity: .tip, message: "UV 9 · 4 min outside, wear sunscreen"),
                try PlanFinding(factor: .openingHours, severity: .fine, message: "Open until 6 pm."),
                try PlanFinding(factor: .crowds, severity: .fine, message: "Usually quiet · estimate")
            ],
            onTheWay: OnTheWayConditions(
                feelsLikeC: 31, uvIndex: 9, rainChance: 10, airQuality: .good,
                maxFeelsLikeC: 32, maxUVIndex: 8, maxRainChance: 40, worstAcceptableAirQuality: .fair
            ),
            chart: nil,
            topOption: nil
        )

        let readBack = try NotificationPayload(userInfo: payload.userInfo())

        #expect(readBack == payload)
    }

    @Test("A plan-affected payload carries the chart hours and the top option")
    func planAffectedCarriesChartAndOption() throws {
        let day = try LinsThursday()
        // AffectedExpanded: air quality at Enmore Park from 6 am to 12 pm, limit Fair.
        let hours = try day.hourlyConditions().filter { $0.time >= day.time(6) && $0.time < day.time(12) }
        let payload = NotificationPayload(
            planID: day.run.id,
            situation: .planAffected,
            planTitle: "Run",
            planStart: day.time(7),
            placeName: "Enmore Park",
            leaveBy: day.time(6, 55),
            travel: TravelEstimate(minutes: 5, mode: .walking),
            findings: [
                try PlanFinding(factor: .conditions, severity: .problem,
                                message: "Smoke until 10 am. Air quality Poor, above your limit (Fair).")
            ],
            onTheWay: nil,
            chart: ConditionChartData(
                conditionName: "Air quality",
                valueName: "PM2.5 (µg/m³)",
                points: hours.map { ConditionChartData.Point(time: $0.time, value: $0.pm25) },
                limit: 50,
                limitLabel: "Your limit (Fair)"
            ),
            topOption: OptionSummary(
                title: "Move to 5:30 pm · Enmore Park",
                explanation: "Air quality returns to Good and UV is low.",
                scheduleNote: "Grocery run moves from 5:30 to 6:30 pm. Your 11 am client call is not affected."
            )
        )

        let readBack = try NotificationPayload(userInfo: payload.userInfo())

        #expect(readBack == payload)
        let chart = try #require(readBack.chart)
        #expect(chart.points.map(\.time) == (6..<12).map { day.time($0) })
        #expect(chart.points.first?.value == 60 && chart.points.last?.value == 12)
        #expect(chart.limit == 50)
        #expect(readBack.topOption?.title == "Move to 5:30 pm · Enmore Park")
    }
}
