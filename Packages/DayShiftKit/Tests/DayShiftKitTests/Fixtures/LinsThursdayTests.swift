import Foundation
import Testing
@testable import DayShiftKit

struct LinsThursdayTests {
    @Test("Lin's Thursday has four plans that fit their own windows")
    func fourPlansFitTheirWindows() throws {
        let day = try LinsThursday()

        #expect(day.plans.map(\.title) == ["Run", "Client call", "Focus work", "Grocery run"])
        #expect(day.places.map(\.name) == ["Home", "Newtown Library", "Enmore Park", "Marrickville Metro"])

        for plan in day.plans {
            #expect(day.calendar.isDate(plan.start, inSameDayAs: day.now))
            #expect(plan.start > day.now, "\(plan.title) hasn't started at 6:40 am")
            if let window = plan.flexibility.movableWindow {
                #expect(window.start <= plan.start && plan.end <= window.end, "\(plan.title) fits its window")
            }
            if let place = plan.place {
                #expect(day.places.contains(place), "\(plan.title) is at one of Lin's places")
            }
        }

        #expect(day.clientCall.mode == .online && day.clientCall.place == nil)
        #expect(day.clientCall.flexibility.allowsAnyChange == false)
    }
}
