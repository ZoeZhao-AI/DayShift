import Foundation

/// A kind of activity, such as Run. One scheduled activity is a plan.
/// Types come from `ActivityCatalogue` and are not stored in Core Data.
public struct ActivityType: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let symbolName: String
    public let purpose: ActivityPurpose
    /// Conditions checked when this activity happens at an outdoor place.
    public let sensitivities: Set<ConditionSensitivity>
    public let suitablePlaceKinds: Set<PlaceKind>
    public let canBeOnline: Bool

    public init(
        id: String,
        name: String,
        symbolName: String,
        purpose: ActivityPurpose,
        sensitivities: Set<ConditionSensitivity>,
        suitablePlaceKinds: Set<PlaceKind>,
        canBeOnline: Bool
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.purpose = purpose
        self.sensitivities = sensitivities
        self.suitablePlaceKinds = suitablePlaceKinds
        self.canBeOnline = canBeOnline
    }
}

extension ActivityType {
    /// Exercise done outdoors: every suitable kind is an outdoor kind
    /// (Run, Walk and Cycling in the catalogue).
    public var isOutdoorExercise: Bool {
        purpose == .exercise && !suitablePlaceKinds.isEmpty
            && suitablePlaceKinds.allSatisfy { !$0.defaultIsIndoor }
    }

    /// Whether Lin can do this activity at the place (2.3): its kind is
    /// suitable, or this is outdoor exercise and the place is an outdoor
    /// place of kind Other, such as "Around home".
    public func suits(_ place: Place) -> Bool {
        if suitablePlaceKinds.contains(place.kind) { return true }
        return isOutdoorExercise && place.kind == .other && !place.isIndoor
    }
}
