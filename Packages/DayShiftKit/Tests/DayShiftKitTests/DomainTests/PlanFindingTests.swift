import Foundation
import Testing
@testable import DayShiftKit

struct PlanFindingTests {
    /// UV 9 is above Lin's default limit of 8.
    private let uvOnTheWay = 9.0

    @Test("UV 9 on a 4-minute walk is a tip, not a problem")
    func shortTimeOutsideIsTip() throws {
        try #require(uvOnTheWay > ComfortPreferences.default.maxUVIndex)

        let severity = PlanFinding.Severity.forLimitExceededOnTheWay(minutesOutside: 4)

        #expect(severity == .tip)
    }

    @Test("UV 9 on a 10-minute walk is a problem")
    func tenMinutesOutsideIsProblem() throws {
        try #require(uvOnTheWay > ComfortPreferences.default.maxUVIndex)

        let severity = PlanFinding.Severity.forLimitExceededOnTheWay(minutesOutside: 10)

        #expect(severity == .problem)
    }
}
