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
