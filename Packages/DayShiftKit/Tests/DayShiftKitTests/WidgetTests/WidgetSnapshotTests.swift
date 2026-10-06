import Foundation
import Testing
@testable import DayShiftKit

struct WidgetSnapshotTests {
    @Test("The next plan is the first one that hasn't finished")
    func nextPlanIsFirstNotFinished() throws {
        let day = try LinsThursday()

        // 11:10 am: the run is over and the client call is under way.
        let snapshot = WidgetSnapshot(plans: day.plans, checks: [:], now: day.time(11, 10), calendar: day.calendar)

        guard case let .plans(next, following) = snapshot.content else {
            Issue.record("Expected plans, got \(snapshot.content)")
            return
        }
        #expect(next.planID == day.clientCall.id)
        #expect(next.timeText == "11:00 am")
        #expect(next.placeText == "Online")
        #expect(next.status == .inProgress)
        // Medium shows the following two plans, one line each.
        #expect(following.map(\.planID) == [day.focusWork.id, day.groceryRun.id])
    }

    @Test("After the last plan, the widget says that's everything for today")
    func afterLastPlanSaysEverythingIsDone() throws {
        let day = try LinsThursday()

        // 6:30 pm: the grocery run ended at 6:00 pm.
        let snapshot = WidgetSnapshot(plans: day.plans, checks: [:], now: day.time(18, 30), calendar: day.calendar)

        #expect(snapshot.content == .message(title: "That's everything for today.", detail: nil))
    }

    @Test("With no plans today, the widget says the day is clear")
    func noPlansSaysDayIsClear() throws {
        let day = try LinsThursday()

        let snapshot = WidgetSnapshot(plans: [], checks: [:], now: day.now, calendar: day.calendar)

        #expect(snapshot.content == .message(title: "Your day is clear.", detail: "Plan an activity in DayShift."))
    }

    @Test("After the last plan, the widget also shows the next plan coming up")
    func afterLastPlanShowsNextPlanComingUp() throws {
        let day = try LinsThursday()
        let fridayRun = try runOn(day, daysLater: 1)

        // 6:30 pm Thursday: today is done, and Friday's 7 am run is next.
        let snapshot = WidgetSnapshot(
            plans: day.plans, upcoming: [fridayRun], checks: [:],
            now: day.time(18, 30), calendar: day.calendar
        )

        #expect(snapshot.content == .message(title: "That's everything for today.", detail: nil))
        #expect(snapshot.comingUp == WidgetSnapshot.ComingUpLine(
            planID: fridayRun.id,
            title: "Run",
            dayText: "Tomorrow",
            timeText: "7:00 am",
            placeText: "Enmore Park"
        ))
    }

    @Test("With nothing in the next 7 days, the widget shows only the message")
    func nothingInNextSevenDaysShowsOnlyMessage() throws {
        let day = try LinsThursday()
        // A run 8 days later is outside "the next 7 days".
        let laterRun = try runOn(day, daysLater: 8)

        let snapshot = WidgetSnapshot(
            plans: [], upcoming: [laterRun], checks: [:],
            now: day.now, calendar: day.calendar
        )

        #expect(snapshot.content == .message(title: "Your day is clear.", detail: "Plan an activity in DayShift."))
        #expect(snapshot.comingUp == nil)
    }

    /// Lin's 7 am run at Enmore Park, some days after Thursday.
    private func runOn(_ day: LinsThursday, daysLater: Int) throws -> PlannedActivity {
        let start = try #require(day.calendar.date(byAdding: .day, value: daysLater, to: day.time(7)))
        return try PlannedActivity(
            typeID: ActivityCatalogue.run.id, title: "Run",
            start: start, durationMinutes: 45,
            place: day.enmorePark, mode: .inPerson,
            flexibility: .fixed
        )
    }

    @Test("The timeline has an entry at each plan's start and end")
    func timelineHasEntryAtEachStartAndEnd() throws {
        let day = try LinsThursday()

        let dates = WidgetSnapshot.timelineDates(plans: day.plans, now: day.now)

        #expect(dates == [
            day.now,                              // 6:40 am
            day.time(7), day.time(7, 45),         // Run
            day.time(11), day.time(11, 30),       // Client call
            day.time(13), day.time(17),           // Focus work
            day.time(17, 30), day.time(18)        // Grocery run
        ])
    }
}
