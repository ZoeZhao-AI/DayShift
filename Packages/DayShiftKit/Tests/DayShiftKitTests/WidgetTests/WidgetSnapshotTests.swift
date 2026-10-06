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
