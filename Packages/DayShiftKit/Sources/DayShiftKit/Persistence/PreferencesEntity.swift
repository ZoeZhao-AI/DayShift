import CoreData
import Foundation

/// Stored form of Lin's comfort preferences; a single row.
/// Never leaves the Persistence folder.
@objc(PreferencesEntity)
final class PreferencesEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PreferencesEntity> {
        NSFetchRequest<PreferencesEntity>(entityName: "PreferencesEntity")
    }

    @NSManaged var maxApparentTemperatureC: Double
    @NSManaged var worstAcceptableAirQualityRaw: String
    @NSManaged var maxUVIndex: Double
    @NSManaged var maxWindGustsKmh: Double
    @NSManaged var maxRainProbability: Int16
    /// Minutes after midnight.
    @NSManaged var earliestPlanTime: Int16
    /// Minutes after midnight.
    @NSManaged var latestPlanTime: Int16
    @NSManaged var minimumBufferMinutes: Int16
    @NSManaged var leaveReminderMinutes: Int16
    @NSManaged var travelModeRaw: String
}
