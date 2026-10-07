import Foundation
import Testing
@testable import DayShiftKit

struct AirQualityCategoryTests {
    @Test("Exactly 50 µg/m³ is still Fair")
    func boundariesBelongToTheLowerCategory() {
        // NSW 1-hour PM2.5: Fair 25–50, Poor above 50 to 100, Very poor above 100 to 300.
        #expect(AirQualityCategory(pm25: 50) == .fair)
        #expect(AirQualityCategory(pm25: 100) == .poor)
        #expect(AirQualityCategory(pm25: 300) == .veryPoor)
        // Just above each boundary is the next category.
        #expect(AirQualityCategory(pm25: 50.1) == .poor)
        #expect(AirQualityCategory(pm25: 100.1) == .veryPoor)
        #expect(AirQualityCategory(pm25: 300.1) == .extremelyPoor)
        // Below 25 is Good; 25 itself starts Fair.
        #expect(AirQualityCategory(pm25: 24.9) == .good)
        #expect(AirQualityCategory(pm25: 25) == .fair)
        // Lin's Fair limit (50) agrees with the category: 50 is not above Fair.
        #expect(AirQualityCategory(pm25: AirQualityCategory.fair.pm25UpperBound ?? 0) == .fair)
    }
}
