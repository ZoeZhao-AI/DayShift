import Foundation

/// The fixed list of activities Lin can plan.
public enum ActivityCatalogue {
    private static let outdoorConditions: Set<ConditionSensitivity> = [
        .heat, .poorAirQuality, .uv, .wind, .rain
    ]
    private static let workPlaces: Set<PlaceKind> = [
        .home, .library, .cafe, .coworkingSpace, .office
    ]

    public static let run = ActivityType(
        id: "run", name: "Run", symbolName: "figure.run",
        purpose: .exercise, sensitivities: outdoorConditions,
        suitablePlaceKinds: [.park, .beach], canBeOnline: false
    )
    public static let walk = ActivityType(
        id: "walk", name: "Walk", symbolName: "figure.walk",
        purpose: .exercise, sensitivities: [.heat, .poorAirQuality, .uv, .rain],
        suitablePlaceKinds: [.park, .beach], canBeOnline: false
    )
    public static let cycling = ActivityType(
        id: "cycling", name: "Cycling", symbolName: "figure.outdoor.cycle",
        purpose: .exercise, sensitivities: outdoorConditions,
        suitablePlaceKinds: [.park], canBeOnline: false
    )
    public static let indoorSwim = ActivityType(
        id: "indoorSwim", name: "Indoor swim", symbolName: "figure.pool.swim",
        purpose: .exercise, sensitivities: [],
        suitablePlaceKinds: [.pool], canBeOnline: false
    )
    public static let gymSession = ActivityType(
        id: "gymSession", name: "Gym session", symbolName: "dumbbell.fill",
        purpose: .exercise, sensitivities: [],
        suitablePlaceKinds: [.gym], canBeOnline: false
    )
    public static let focusWork = ActivityType(
        id: "focusWork", name: "Focus work", symbolName: "laptopcomputer",
        purpose: .work, sensitivities: [],
        suitablePlaceKinds: workPlaces, canBeOnline: false
    )
    public static let clientMeeting = ActivityType(
        id: "clientMeeting", name: "Client meeting", symbolName: "person.2.fill",
        purpose: .work, sensitivities: [],
        suitablePlaceKinds: [.cafe, .coworkingSpace, .office], canBeOnline: true
    )
    public static let coffeeWithAFriend = ActivityType(
        id: "coffeeWithAFriend", name: "Coffee with a friend", symbolName: "cup.and.saucer.fill",
        purpose: .socialising, sensitivities: [],
        suitablePlaceKinds: [.cafe], canBeOnline: false
    )
    public static let picnic = ActivityType(
        id: "picnic", name: "Picnic", symbolName: "basket.fill",
        purpose: .socialising, sensitivities: outdoorConditions,
        suitablePlaceKinds: [.park, .beach], canBeOnline: false
    )
    public static let outdoorSketching = ActivityType(
        id: "outdoorSketching", name: "Outdoor sketching", symbolName: "pencil.and.scribble",
        purpose: .relaxationAndCreative, sensitivities: outdoorConditions,
        suitablePlaceKinds: [.park, .beach], canBeOnline: false
    )
    public static let galleryVisit = ActivityType(
        id: "galleryVisit", name: "Gallery visit", symbolName: "building.columns.fill",
        purpose: .relaxationAndCreative, sensitivities: [],
        suitablePlaceKinds: [.galleryOrMuseum], canBeOnline: false
    )
    public static let groceryRun = ActivityType(
        id: "groceryRun", name: "Grocery run", symbolName: "cart.fill",
        purpose: .errands, sensitivities: [],
        suitablePlaceKinds: [.shoppingCentre], canBeOnline: false
    )

    /// All activities, in the order of Section 2.3.
    public static let all: [ActivityType] = [
        run, walk, cycling, indoorSwim, gymSession, focusWork,
        clientMeeting, coffeeWithAFriend, picnic, outdoorSketching,
        galleryVisit, groceryRun
    ]

    /// The activity type stored in a plan's `typeID`, or nil if it is unknown.
    public static func type(withID id: String) -> ActivityType? {
        all.first { $0.id == id }
    }
}
