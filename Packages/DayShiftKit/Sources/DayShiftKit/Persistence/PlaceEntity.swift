import CoreData
import Foundation

/// Stored form of a place. Never leaves the Persistence folder.
@objc(PlaceEntity)
final class PlaceEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PlaceEntity> {
        NSFetchRequest<PlaceEntity>(entityName: "PlaceEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var kindRaw: String
    @NSManaged var address: String
    @NSManaged var suburb: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var isIndoor: Bool
    @NSManaged var isCooled: Bool
    @NSManaged var uncooledHeatLimitC: NSNumber?
    @NSManaged var isAlwaysOpen: Bool
    /// Minutes after midnight.
    @NSManaged var opensAt: NSNumber?
    /// Minutes after midnight.
    @NSManaged var closesAt: NSNumber?
    /// Comma-separated `Calendar` weekdays, e.g. "1,7"; empty if never closed.
    @NSManaged var closedWeekdays: String

    /// Delete rule Deny: a place with plans can't be deleted.
    @NSManaged var activities: Set<ActivityEntity>
}
