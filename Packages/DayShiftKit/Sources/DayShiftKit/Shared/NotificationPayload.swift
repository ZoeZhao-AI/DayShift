import Foundation

/// Everything a notification's expanded view needs (Section 6.3), carried in
/// its `userInfo` so the Notification Content Extension needs no network
/// and no store.
public struct NotificationPayload: Codable, Equatable, Sendable {
    public enum Situation: String, Codable, Sendable {
        /// A: "Leave in 10 min for Focus work".
        case leaveReminder
        /// B: "Your 7:00 am run is affected".
        case planAffected
    }

    public let planID: UUID
    public let situation: Situation
    public let planTitle: String
    public let planStart: Date
    /// nil for an online plan.
    public let placeName: String?
    public let leaveBy: Date?
    public let travel: TravelEstimate?
    /// The plan's latest check: on-the-way tips and the destination rows.
    public let findings: [PlanFinding]
    /// A: the "On the way" values with Lin's limits.
    public let onTheWay: OnTheWayConditions?
    /// B: the hours of the problem condition, with Lin's limit.
    public let chart: ConditionChartData?
    /// B: the best option, if there is one.
    public let topOption: OptionSummary?

    public init(
        planID: UUID,
        situation: Situation,
        planTitle: String,
        planStart: Date,
        placeName: String?,
        leaveBy: Date?,
        travel: TravelEstimate?,
        findings: [PlanFinding],
        onTheWay: OnTheWayConditions?,
        chart: ConditionChartData?,
        topOption: OptionSummary?
    ) {
        self.planID = planID
        self.situation = situation
        self.planTitle = planTitle
        self.planStart = planStart
        self.placeName = placeName
        self.leaveBy = leaveBy
        self.travel = travel
        self.findings = findings
        self.onTheWay = onTheWay
        self.chart = chart
        self.topOption = topOption
    }

    // MARK: - userInfo

    /// The key the payload's JSON is stored under in `userInfo`.
    public static let userInfoKey = "dayshiftPayload"

    /// `userInfo` only takes property-list values, so the payload is stored
    /// as one JSON string.
    public func userInfo() throws -> [AnyHashable: Any] {
        let data = try JSONEncoder().encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NotificationPayloadError.unreadable
        }
        return [Self.userInfoKey: json]
    }

    public init(userInfo: [AnyHashable: Any]) throws {
        guard let json = userInfo[Self.userInfoKey] as? String else {
            throw NotificationPayloadError.missing
        }
        self = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
    }
}

public enum NotificationPayloadError: Error, Equatable {
    /// The notification has no DayShift payload.
    case missing
    /// The payload couldn't be turned into text.
    case unreadable
}

/// The "On the way" rows of a leave reminder (LeaveExpanded), each with
/// Lin's limit: "31°C feels like (your limit 32°C)".
public struct OnTheWayConditions: Codable, Equatable, Sendable {
    public let feelsLikeC: Double
    public let uvIndex: Double
    /// 0–100 %.
    public let rainChance: Int
    public let airQuality: AirQualityCategory
    public let maxFeelsLikeC: Double
    public let maxUVIndex: Double
    public let maxRainChance: Int
    public let worstAcceptableAirQuality: AirQualityCategory

    public init(
        feelsLikeC: Double,
        uvIndex: Double,
        rainChance: Int,
        airQuality: AirQualityCategory,
        maxFeelsLikeC: Double,
        maxUVIndex: Double,
        maxRainChance: Int,
        worstAcceptableAirQuality: AirQualityCategory
    ) {
        self.feelsLikeC = feelsLikeC
        self.uvIndex = uvIndex
        self.rainChance = rainChance
        self.airQuality = airQuality
        self.maxFeelsLikeC = maxFeelsLikeC
        self.maxUVIndex = maxUVIndex
        self.maxRainChance = maxRainChance
        self.worstAcceptableAirQuality = worstAcceptableAirQuality
    }
}

/// The problem condition by the hour and Lin's limit, for the chart in a
/// plan-affected notification (AffectedExpanded).
public struct ConditionChartData: Codable, Equatable, Sendable {
    public struct Point: Codable, Equatable, Sendable {
        public let time: Date
        public let value: Double

        public init(time: Date, value: Double) {
            self.time = time
            self.value = value
        }
    }

    /// e.g. "Air quality".
    public let conditionName: String
    /// The axis title, e.g. "PM2.5 (µg/m³)".
    public let valueName: String
    public let points: [Point]
    public let limit: Double
    /// e.g. "Your limit (Fair)".
    public let limitLabel: String

    public init(conditionName: String, valueName: String, points: [Point], limit: Double, limitLabel: String) {
        self.conditionName = conditionName
        self.valueName = valueName
        self.points = points
        self.limit = limit
        self.limitLabel = limitLabel
    }
}

/// The best option, as its card shows it: "Move to 5:30 pm · Enmore Park".
public struct OptionSummary: Codable, Equatable, Sendable {
    public let title: String
    public let explanation: String
    public let scheduleNote: String

    public init(title: String, explanation: String, scheduleNote: String) {
        self.title = title
        self.explanation = explanation
        self.scheduleNote = scheduleNote
    }
}
