import CoreData
import Foundation

/// Stored form of an accepted change. Never leaves the Persistence folder.
@objc(AdjustmentRecordEntity)
final class AdjustmentRecordEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AdjustmentRecordEntity> {
        NSFetchRequest<AdjustmentRecordEntity>(entityName: "AdjustmentRecordEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var kindRaw: String
    @NSManaged var previousStart: Date
    @NSManaged var newStart: Date
    @NSManaged var previousPlaceName: String?
    @NSManaged var newPlaceName: String?
    @NSManaged var reason: String
    @NSManaged var acceptedAt: Date

    @NSManaged var activity: ActivityEntity?
}
