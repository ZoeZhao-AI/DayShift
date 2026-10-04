import Foundation
import Testing
@testable import DayShiftKit

struct DayScheduleTests {
    @Test("The gap between plans is the larger of buffer and travel time")
    func requiredGapIsLargerOfBufferAndTravel() {
        #expect(DaySchedule.requiredGap(travelMinutes: 25, buffer: 15) == 25)
        #expect(DaySchedule.requiredGap(travelMinutes: 8, buffer: 15) == 15)
    }

    @Test("A gap of exactly 15 minutes is enough when the buffer is 15 minutes")
    func exactlyFifteenMinutesIsEnough() throws {
        let day = try LinsThursday()
        let run = day.run
        let schedule = DaySchedule(date: day.now, plans: [run])

        let startsFifteenMinutesAfterRun = DateInterval(start: day.time(8), end: day.time(8, 30))
        let startsFourteenMinutesAfterRun = DateInterval(start: day.time(7, 59), end: day.time(8, 29))

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
        let day = try LinsThursday()
        let call = day.clientCall
        let schedule = DaySchedule(date: day.now, plans: [call])

        let meetingAt1045 = DateInterval(start: day.time(10, 45), end: day.time(11, 30))

        #expect(schedule.conflicts(
            for: meetingAt1045,
            travelBefore: 0, travelAfter: 0, excluding: [], buffer: 15
        ) == [.overlaps(planID: call.id)])
    }
}
