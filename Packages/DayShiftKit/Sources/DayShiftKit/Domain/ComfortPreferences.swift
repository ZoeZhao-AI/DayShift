import Foundation

/// Lin's limits for conditions, planning hours and reminders.
public struct ComfortPreferences: Hashable, Sendable {
    /// A value that has a valid range, for error messages.
    public enum Field: String, CaseIterable, Hashable, Sendable {
        case maxApparentTemperature
        case worstAcceptableAirQuality
        case maxUVIndex
        case maxWindGusts
        case maxRainProbability
        case minimumBuffer
        case leaveReminder
    }

    public static let maxApparentTemperatureRange = 20.0...45.0
    public static let worstAcceptableAirQualityRange = AirQualityCategory.good...AirQualityCategory.poor
    public static let maxUVIndexRange = 1.0...15.0
    public static let maxWindGustsRange = 10.0...120.0
    public static let maxRainProbabilityRange = 0...100
    public static let minimumBufferRange = 0...120
    public static let leaveReminderRange = 5...30

    public static let `default` = ComfortPreferences(
        validatedMaxApparentTemperatureC: 32,
        worstAcceptableAirQuality: .fair,
        maxUVIndex: 8,
        maxWindGustsKmh: 40,
        maxRainProbability: 40,
        earliestPlanTime: 6 * 60,
        latestPlanTime: 21 * 60,
        minimumBufferMinutes: 15,
        leaveReminderMinutes: 10,
        travelMode: .publicTransport
    )

    public let maxApparentTemperatureC: Double
    public let worstAcceptableAirQuality: AirQualityCategory
    public let maxUVIndex: Double
    public let maxWindGustsKmh: Double
    /// Highest acceptable chance of rain, 0–100 %.
    public let maxRainProbability: Int
    /// Minutes after midnight.
    public let earliestPlanTime: Int
    /// Minutes after midnight.
    public let latestPlanTime: Int
    public let minimumBufferMinutes: Int
    /// Minutes before "leave by" that the leave reminder fires.
    public let leaveReminderMinutes: Int
    public let travelMode: TravelMode

    public init(
        maxApparentTemperatureC: Double,
        worstAcceptableAirQuality: AirQualityCategory,
        maxUVIndex: Double,
        maxWindGustsKmh: Double,
        maxRainProbability: Int,
        earliestPlanTime: Int,
        latestPlanTime: Int,
        minimumBufferMinutes: Int,
        leaveReminderMinutes: Int,
        travelMode: TravelMode
    ) throws {
        let checks: [(Field, Bool)] = [
            (.maxApparentTemperature, Self.maxApparentTemperatureRange.contains(maxApparentTemperatureC)),
            (.worstAcceptableAirQuality, Self.worstAcceptableAirQualityRange.contains(worstAcceptableAirQuality)),
            (.maxUVIndex, Self.maxUVIndexRange.contains(maxUVIndex)),
            (.maxWindGusts, Self.maxWindGustsRange.contains(maxWindGustsKmh)),
            (.maxRainProbability, Self.maxRainProbabilityRange.contains(maxRainProbability)),
            (.minimumBuffer, Self.minimumBufferRange.contains(minimumBufferMinutes)),
            (.leaveReminder, Self.leaveReminderRange.contains(leaveReminderMinutes))
        ]
        if let (field, _) = checks.first(where: { !$0.1 }) {
            throw ComfortPreferencesError.valueOutOfRange(field)
        }
        guard earliestPlanTime < latestPlanTime else {
            throw ComfortPreferencesError.planningHoursInvalid
        }

        self.init(
            validatedMaxApparentTemperatureC: maxApparentTemperatureC,
            worstAcceptableAirQuality: worstAcceptableAirQuality,
            maxUVIndex: maxUVIndex,
            maxWindGustsKmh: maxWindGustsKmh,
            maxRainProbability: maxRainProbability,
            earliestPlanTime: earliestPlanTime,
            latestPlanTime: latestPlanTime,
            minimumBufferMinutes: minimumBufferMinutes,
            leaveReminderMinutes: leaveReminderMinutes,
            travelMode: travelMode
        )
    }

    /// Stores values that are already known to be valid.
    private init(
        validatedMaxApparentTemperatureC maxApparentTemperatureC: Double,
        worstAcceptableAirQuality: AirQualityCategory,
        maxUVIndex: Double,
        maxWindGustsKmh: Double,
        maxRainProbability: Int,
        earliestPlanTime: Int,
        latestPlanTime: Int,
        minimumBufferMinutes: Int,
        leaveReminderMinutes: Int,
        travelMode: TravelMode
    ) {
        self.maxApparentTemperatureC = maxApparentTemperatureC
        self.worstAcceptableAirQuality = worstAcceptableAirQuality
        self.maxUVIndex = maxUVIndex
        self.maxWindGustsKmh = maxWindGustsKmh
        self.maxRainProbability = maxRainProbability
        self.earliestPlanTime = earliestPlanTime
        self.latestPlanTime = latestPlanTime
        self.minimumBufferMinutes = minimumBufferMinutes
        self.leaveReminderMinutes = leaveReminderMinutes
        self.travelMode = travelMode
    }
}

public enum ComfortPreferencesError: Error, Equatable {
    case valueOutOfRange(ComfortPreferences.Field)
    case planningHoursInvalid
}
