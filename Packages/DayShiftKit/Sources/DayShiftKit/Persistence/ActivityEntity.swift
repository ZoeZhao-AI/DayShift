import CoreData
import Foundation

/// Stored form of a plan. Never leaves the Persistence folder.
@objc(ActivityEntity)
final class ActivityEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ActivityEntity> {
        NSFetchRequest<ActivityEntity>(entityName: "ActivityEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var start: Date
}
