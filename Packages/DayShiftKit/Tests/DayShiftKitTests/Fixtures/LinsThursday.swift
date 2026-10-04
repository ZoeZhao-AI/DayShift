import Foundation
@testable import DayShiftKit

/// Lin's Thursday from Section 8.2: a smoky morning, a hot afternoon and
/// high UV around midday, with four plans and four places.
/// Coordinates are approximate.
struct LinsThursday {
    static let sydney: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }()

    let calendar = LinsThursday.sydney

    /// Thursday 6:40 am.
    let now: Date
    let preferences = ComfortPreferences.default

    // MARK: Places
    /// Uncooled; too hot above 30°C outside.
    let home: Place
    /// Cooled; open 9 am–6 pm.
    let newtownLibrary: Place
    let enmorePark: Place
    /// Cooled; open until 9 pm.
    let marrickvilleMetro: Place

    // MARK: Plans
    /// 7:00–7:45 am at Enmore Park; may move between 6:00 am and 9:00 pm.
    let run: PlannedActivity
    /// 11:00–11:30 am, online, fixed.
    let clientCall: PlannedActivity
    /// 1:00–5:00 pm at Home; may change place.
    let focusWork: PlannedActivity
    /// 5:30–6:00 pm at Marrickville Metro; may move between 4:00 and 8:30 pm.
    let groceryRun: PlannedActivity

    var places: [Place] { [home, newtownLibrary, enmorePark, marrickvilleMetro] }
    var plans: [PlannedActivity] { [run, clientCall, focusWork, groceryRun] }

    init() throws {
        now = Self.time(6, 40)

        home = try Place(
            name: "Home", kind: .home, address: "Enmore NSW 2042",
            latitude: -33.9000, longitude: 151.1740, suburb: "Enmore",
            isIndoor: true, isCooled: false, uncooledHeatLimitC: 30,
            isAlwaysOpen: true
        )
        newtownLibrary = try Place(
            name: "Newtown Library", kind: .library, address: "8–10 Brown St, Newtown NSW 2042",
            latitude: -33.8975, longitude: 151.1790, suburb: "Newtown",
            isIndoor: true, isCooled: true,
            isAlwaysOpen: false,
            openingHours: OpeningHours(opensAt: 9 * 60, closesAt: 18 * 60, closedWeekdays: [])
        )
        enmorePark = try Place(
            name: "Enmore Park", kind: .park, address: "Enmore Rd, Marrickville NSW 2204",
            latitude: -33.9035, longitude: 151.1685, suburb: "Marrickville",
            isIndoor: false, isCooled: false,
            isAlwaysOpen: true
        )
        marrickvilleMetro = try Place(
            name: "Marrickville Metro", kind: .shoppingCentre, address: "34 Victoria Rd, Marrickville NSW 2204",
            latitude: -33.9110, longitude: 151.1650, suburb: "Marrickville",
            isIndoor: true, isCooled: true,
            isAlwaysOpen: false,
            openingHours: OpeningHours(opensAt: 7 * 60, closesAt: 21 * 60, closedWeekdays: [])
        )

        run = try PlannedActivity(
            typeID: ActivityCatalogue.run.id, title: "Run",
            start: Self.time(7), durationMinutes: 45,
            place: enmorePark, mode: .inPerson,
            flexibility: ActivityFlexibility(
                movableWindow: DateInterval(start: Self.time(6), end: Self.time(21)),
                allowsPlaceChange: false
            )
        )
        clientCall = try PlannedActivity(
            typeID: ActivityCatalogue.clientMeeting.id, title: "Client call",
            start: Self.time(11), durationMinutes: 30,
            place: nil, mode: .online,
            flexibility: .fixed
        )
        focusWork = try PlannedActivity(
            typeID: ActivityCatalogue.focusWork.id, title: "Focus work",
            start: Self.time(13), durationMinutes: 240,
            place: home, mode: .inPerson,
            flexibility: ActivityFlexibility(movableWindow: nil, allowsPlaceChange: true)
        )
        groceryRun = try PlannedActivity(
            typeID: ActivityCatalogue.groceryRun.id, title: "Grocery run",
            start: Self.time(17, 30), durationMinutes: 30,
            place: marrickvilleMetro, mode: .inPerson,
            flexibility: ActivityFlexibility(
                movableWindow: DateInterval(start: Self.time(16), end: Self.time(20, 30)),
                allowsPlaceChange: false
            )
        )
    }

    /// Thursday 8 October 2026 at the given time, Sydney time.
    static func time(_ hour: Int, _ minute: Int = 0) -> Date {
        sydney.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    func time(_ hour: Int, _ minute: Int = 0) -> Date {
        Self.time(hour, minute)
    }

    /// Hourly conditions for the whole day, the same at every place:
    /// - PM2.5 60 µg/m³ (poor) until 10 am, then 12 (good)
    /// - 33°C from 2 to 4 pm, otherwise 24°C
    /// - UV 9 from 11 am to 3 pm, otherwise 3
    /// Rain 10 % and gusts 20 km/h all day.
    func hourlyConditions() throws -> [HourlyConditions] {
        try (0..<24).map { hour in
            let temperature: Double = (14..<16).contains(hour) ? 33 : 24
            return try HourlyConditions(
                time: time(hour),
                temperatureC: temperature,
                apparentTemperatureC: temperature,
                precipitationProbability: 10,
                uvIndex: (11..<15).contains(hour) ? 9 : 3,
                windGustsKmh: 20,
                pm25: hour < 10 ? 60 : 12
            )
        }
    }

    /// The day's forecast at a place, fetched at `now`.
    func forecast(at place: Place) throws -> ConditionsForecast {
        ConditionsForecast(
            latitude: place.latitude,
            longitude: place.longitude,
            fetchedAt: now,
            hours: try hourlyConditions()
        )
    }
}
