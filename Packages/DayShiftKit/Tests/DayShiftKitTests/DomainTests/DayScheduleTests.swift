import Foundation
import Testing
@testable import DayShiftKit

struct DayScheduleTests {
    private let sydney: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }()

    /// Thursday 8 October 2026 at the given time, Sydney time.
    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date {
        sydney.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    /// Run 7:00–7:45 am at Enmore Park.
    private func morningRun() throws -> PlannedActivity {
        let park = try Place(
            name: "Enmore Park",
            kind: .park,
            address: "Enmore Rd, Marrickville NSW 2204",
            latitude: -33.8990,
            longitude: 151.1720,
            isIndoor: false,
            isCooled: false,
            isAlwaysOpen: true
        )
        return try PlannedActivity(
            typeID: ActivityCatalogue.run.id,
            title: "Run",
            start: thursday(7),
            durationMinutes: 45,
            place: park,
            mode: .inPerson,
            flexibility: .fixed
        )
    }

    /// Client call 11:00–11:30 am, online and fixed.
    private func clientCall() throws -> PlannedActivity {
        try PlannedActivity(
            typeID: ActivityCatalogue.clientMeeting.id,
            title: "Client call",
            start: thursday(11),
            durationMinutes: 30,
            place: nil,
            mode: .online,
            flexibility: .fixed
        )
    }

    @Test("The gap between plans is the larger of buffer and travel time")
    func requiredGapIsLargerOfBufferAndTravel() {
        #expect(DaySchedule.requiredGap(travelMinutes: 25, buffer: 15) == 25)
        #expect(DaySchedule.requiredGap(travelMinutes: 8, buffer: 15) == 15)
    }

    @Test("A gap of exactly 15 minutes is enough when the buffer is 15 minutes")
    func exactlyFifteenMinutesIsEnough() throws {
        let run = try morningRun()
        let schedule = DaySchedule(date: thursday(0), plans: [run])

        let startsFifteenMinutesAfterRun = DateInterval(start: thursday(8), end: thursday(8, 30))
        let startsFourteenMinutesAfterRun = DateInterval(start: thursday(7, 59), end: thursday(8, 29))

        #expect(schedule.conflicts(
            for: startsFifteenMinutesAfterRun,
            travelBefore: 10, travelAfter: 0, excluding: [], buffer: 15
        ).isEmpty)
        #expect(schedule.conflicts(
            for: startsFourteenMinutesAfterRun,
            travelBefore: 10, travelAfter: 0, excluding: [], buffer: 15
        ) == [.notEnoughGap(planID: run.id, available: 14, required: 15)])
    }

    @Test("A plan overlapping the 11 am client call is reported as overlaps")
    func overlappingPlanIsReported() throws {
        let call = try clientCall()
        let schedule = DaySchedule(date: thursday(0), plans: [call])

        let meetingAt1045 = DateInterval(start: thursday(10, 45), end: thursday(11, 30))

        #expect(schedule.conflicts(
            for: meetingAt1045,
            travelBefore: 0, travelAfter: 0, excluding: [], buffer: 15
        ) == [.overlaps(planID: call.id)])
    }
}
