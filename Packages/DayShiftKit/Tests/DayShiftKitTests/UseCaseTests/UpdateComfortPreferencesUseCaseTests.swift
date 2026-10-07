import Foundation
import Testing
@testable import DayShiftKit

struct UpdateComfortPreferencesUseCaseTests {
    private struct Setup {
        let preferences = MockPreferencesRepository()
        let widget = MockWidgetRefresher()
        let useCase: UpdateComfortPreferencesUseCase

        init() {
            useCase = UpdateComfortPreferencesUseCase(preferences: preferences, widget: widget)
        }
    }

    @Test("A temperature limit above 45°C is rejected")
    func temperatureAbove45IsRejected() async throws {
        let setup = Setup()
        var draft = ComfortPreferencesDraft(.default)
        draft.maxApparentTemperatureC = 46

        let expected = UpdateComfortPreferencesError.valueOutOfRange(.maxApparentTemperature)
        await #expect(throws: expected) {
            try await setup.useCase.execute(draft)
        }
        // 3.5's wording: what went wrong, then what to do next.
        #expect(expected.errorDescription == "Max feels-like temperature needs to be between 20°C and 45°C.")
        #expect(expected.recoverySuggestion == "Enter a value in this range.")
        #expect(setup.preferences.savedPreferences.isEmpty)
        #expect(setup.widget.reloadCount == 0)
    }

    @Test("An earliest planning time after the latest is rejected")
    func earliestAfterLatestIsRejected() async throws {
        let setup = Setup()
        var draft = ComfortPreferencesDraft(.default)
        draft.earliestPlanTime = 22 * 60   // 10:00 pm
        draft.latestPlanTime = 21 * 60     // 9:00 pm

        await #expect(throws: UpdateComfortPreferencesError.planningHoursInvalid) {
            try await setup.useCase.execute(draft)
        }
        #expect(setup.preferences.savedPreferences.isEmpty)
        #expect(setup.widget.reloadCount == 0)
    }
}
