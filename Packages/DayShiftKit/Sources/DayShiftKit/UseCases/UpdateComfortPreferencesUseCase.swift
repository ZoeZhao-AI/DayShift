import Foundation

/// The Settings editors' values before they are checked. `ComfortPreferences`
/// can't hold a value out of range, so the editors change these instead.
public struct ComfortPreferencesDraft: Equatable, Sendable {
    public var maxApparentTemperatureC: Double
    public var worstAcceptableAirQuality: AirQualityCategory
    public var maxUVIndex: Double
    public var maxWindGustsKmh: Double
    public var maxRainProbability: Int
    /// Minutes after midnight.
    public var earliestPlanTime: Int
    /// Minutes after midnight.
    public var latestPlanTime: Int
    public var minimumBufferMinutes: Int
    public var leaveReminderMinutes: Int
    public var travelMode: TravelMode

    /// Starts from the current preferences.
    public init(_ preferences: ComfortPreferences) {
        maxApparentTemperatureC = preferences.maxApparentTemperatureC
        worstAcceptableAirQuality = preferences.worstAcceptableAirQuality
        maxUVIndex = preferences.maxUVIndex
        maxWindGustsKmh = preferences.maxWindGustsKmh
        maxRainProbability = preferences.maxRainProbability
        earliestPlanTime = preferences.earliestPlanTime
        latestPlanTime = preferences.latestPlanTime
        minimumBufferMinutes = preferences.minimumBufferMinutes
        leaveReminderMinutes = preferences.leaveReminderMinutes
        travelMode = preferences.travelMode
    }
}

/// Why the preferences couldn't be saved (Section 3.5). Says what went wrong
/// and what to do next. The field's name and range come from 2.7.
public enum UpdateComfortPreferencesError: LocalizedError, Equatable {
    case valueOutOfRange(ComfortPreferences.Field)
    case planningHoursInvalid

    public var errorDescription: String? {
        switch self {
        case let .valueOutOfRange(field):
            return "\(field.displayName) needs to be between \(field.rangeText)."
        case .planningHoursInvalid:
            return "Your earliest planning time needs to be before your latest."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .valueOutOfRange: return "Enter a value in this range."
        case .planningHoursInvalid: return "Adjust one of the times."
        }
    }
}

extension ComfortPreferences.Field {
    /// How Settings names the value, e.g. "Max feels-like temperature".
    public var displayName: String {
        switch self {
        case .maxApparentTemperature: return "Max feels-like temperature"
        case .worstAcceptableAirQuality: return "Worst air quality"
        case .maxUVIndex: return "Max UV"
        case .maxWindGusts: return "Max wind gusts"
        case .maxRainProbability: return "Max chance of rain"
        case .minimumBuffer: return "Time between plans"
        case .leaveReminder: return "Leave reminder"
        }
    }

    /// The valid range from 2.7, e.g. "20°C and 45°C".
    public var rangeText: String {
        func whole(_ value: Double) -> String { String(Int(value.rounded())) }
        switch self {
        case .maxApparentTemperature:
            let range = ComfortPreferences.maxApparentTemperatureRange
            return "\(whole(range.lowerBound))°C and \(whole(range.upperBound))°C"
        case .worstAcceptableAirQuality:
            let range = ComfortPreferences.worstAcceptableAirQualityRange
            return "\(range.lowerBound.name) and \(range.upperBound.name)"
        case .maxUVIndex:
            let range = ComfortPreferences.maxUVIndexRange
            return "\(whole(range.lowerBound)) and \(whole(range.upperBound))"
        case .maxWindGusts:
            let range = ComfortPreferences.maxWindGustsRange
            return "\(whole(range.lowerBound)) and \(whole(range.upperBound)) km/h"
        case .maxRainProbability:
            let range = ComfortPreferences.maxRainProbabilityRange
            return "\(range.lowerBound)% and \(range.upperBound)%"
        case .minimumBuffer:
            let range = ComfortPreferences.minimumBufferRange
            return "\(range.lowerBound) and \(range.upperBound) minutes"
        case .leaveReminder:
            let range = ComfortPreferences.leaveReminderRange
            return "\(range.lowerBound) and \(range.upperBound) minutes"
        }
    }
}

/// Saves Lin's limits and day settings (Section 3.5): every value within
/// 2.7's ranges, earliest before latest. After saving, the widget reloads;
/// the ViewModel then runs CheckUpcomingPlansUseCase again.
public struct UpdateComfortPreferencesUseCase {
    private let preferences: PreferencesRepository
    private let widget: WidgetRefreshing

    public init(preferences: PreferencesRepository, widget: WidgetRefreshing) {
        self.preferences = preferences
        self.widget = widget
    }

    /// Checks, saves and returns the preferences.
    @discardableResult
    public func execute(_ draft: ComfortPreferencesDraft) async throws -> ComfortPreferences {
        let checked: ComfortPreferences
        do {
            checked = try ComfortPreferences(
                maxApparentTemperatureC: draft.maxApparentTemperatureC,
                worstAcceptableAirQuality: draft.worstAcceptableAirQuality,
                maxUVIndex: draft.maxUVIndex,
                maxWindGustsKmh: draft.maxWindGustsKmh,
                maxRainProbability: draft.maxRainProbability,
                earliestPlanTime: draft.earliestPlanTime,
                latestPlanTime: draft.latestPlanTime,
                minimumBufferMinutes: draft.minimumBufferMinutes,
                leaveReminderMinutes: draft.leaveReminderMinutes,
                travelMode: draft.travelMode
            )
        } catch let ComfortPreferencesError.valueOutOfRange(field) {
            throw UpdateComfortPreferencesError.valueOutOfRange(field)
        } catch ComfortPreferencesError.planningHoursInvalid {
            throw UpdateComfortPreferencesError.planningHoursInvalid
        }

        try await preferences.save(checked)
        widget.reload()
        return checked
    }
}
