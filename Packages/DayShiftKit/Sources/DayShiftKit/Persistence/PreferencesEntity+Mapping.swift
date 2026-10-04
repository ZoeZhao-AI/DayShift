import CoreData
import Foundation

extension PreferencesEntity {
    private static let entityName = "PreferencesEntity"

    /// The stored preferences. Runs the same checks as `ComfortPreferences.init`.
    func comfortPreferences() throws -> ComfortPreferences {
        try ComfortPreferences(
            maxApparentTemperatureC: maxApparentTemperatureC,
            worstAcceptableAirQuality: PersistenceMapping.decodeRaw(
                worstAcceptableAirQualityRaw, as: AirQualityCategory.self,
                entity: Self.entityName, attribute: "worstAcceptableAirQualityRaw"
            ),
            maxUVIndex: maxUVIndex,
            maxWindGustsKmh: maxWindGustsKmh,
            maxRainProbability: Int(maxRainProbability),
            earliestPlanTime: Int(earliestPlanTime),
            latestPlanTime: Int(latestPlanTime),
            minimumBufferMinutes: Int(minimumBufferMinutes),
            leaveReminderMinutes: Int(leaveReminderMinutes),
            travelMode: PersistenceMapping.decodeRaw(
                travelModeRaw, as: TravelMode.self, entity: Self.entityName, attribute: "travelModeRaw"
            )
        )
    }

    func update(from preferences: ComfortPreferences) throws {
        maxApparentTemperatureC = preferences.maxApparentTemperatureC
        worstAcceptableAirQualityRaw = preferences.worstAcceptableAirQuality.rawValue
        maxUVIndex = preferences.maxUVIndex
        maxWindGustsKmh = preferences.maxWindGustsKmh
        maxRainProbability = try int16(preferences.maxRainProbability, "maxRainProbability")
        earliestPlanTime = try int16(preferences.earliestPlanTime, "earliestPlanTime")
        latestPlanTime = try int16(preferences.latestPlanTime, "latestPlanTime")
        minimumBufferMinutes = try int16(preferences.minimumBufferMinutes, "minimumBufferMinutes")
        leaveReminderMinutes = try int16(preferences.leaveReminderMinutes, "leaveReminderMinutes")
        travelModeRaw = preferences.travelMode.rawValue
    }

    private func int16(_ value: Int, _ attribute: String) throws -> Int16 {
        try PersistenceMapping.int16(value, entity: Self.entityName, attribute: attribute)
    }
}
