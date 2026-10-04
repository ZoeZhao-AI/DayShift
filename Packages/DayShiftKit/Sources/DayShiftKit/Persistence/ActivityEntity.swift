import CoreData
import Foundation

/// Stored form of a plan and its latest check. Never leaves the Persistence folder.
@objc(ActivityEntity)
final class ActivityEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ActivityEntity> {
        NSFetchRequest<ActivityEntity>(entityName: "ActivityEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var typeID: String
    @NSManaged var title: String
    @NSManaged var modeRaw: String
    @NSManaged var statusRaw: String
    @NSManaged var start: Date
    /// Stored so overlap queries can use it.
    @NSManaged var end: Date
    @NSManaged var durationMinutes: Int16
    @NSManaged var movableWindowStart: Date?
    @NSManaged var movableWindowEnd: Date?
    @NSManaged var allowsPlaceChange: Bool

    /// "looksGood" or "needsAttention"; nil until the plan is first checked.
    @NSManaged var checkStatusRaw: String?
    @NSManaged var checkSummary: String?
    @NSManaged var checkedAt: Date?
    @NSManaged var leaveBy: Date?
    @NSManaged var travelMinutes: NSNumber?
    @NSManaged var travelModeRaw: String?
    /// JSON-encoded `[PlanFinding]`.
    @NSManaged var findingsData: Data?
    /// Comma-separated, e.g. "poorAirQuality,heat".
    @NSManaged var notifiedReasonKeys: String?

    @NSManaged var place: PlaceEntity?
    @NSManaged var adjustments: Set<AdjustmentRecordEntity>
}
