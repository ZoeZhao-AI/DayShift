import CoreData
import Foundation

extension AdjustmentRecordEntity {
    private static let entityName = "AdjustmentRecordEntity"

    func adjustmentRecord() throws -> AdjustmentRecord {
        guard let activity else {
            throw PersistenceMappingError.missingRelationship(entity: Self.entityName, relationship: "activity")
        }
        return AdjustmentRecord(
            id: id,
            planID: activity.id,
            kind: try PersistenceMapping.decodeRaw(
                kindRaw, as: AdjustmentRecord.Kind.self, entity: Self.entityName, attribute: "kindRaw"
            ),
            previousStart: previousStart,
            newStart: newStart,
            previousPlaceName: previousPlaceName,
            newPlaceName: newPlaceName,
            reason: reason,
            acceptedAt: acceptedAt
        )
    }

    /// - Parameter activityEntity: the stored plan with the id `record.planID`.
    func update(from record: AdjustmentRecord, activityEntity: ActivityEntity) throws {
        guard activityEntity.id == record.planID else {
            throw PersistenceMappingError.mismatchedRelationship(entity: Self.entityName, relationship: "activity")
        }
        id = record.id
        kindRaw = record.kind.rawValue
        previousStart = record.previousStart
        newStart = record.newStart
        previousPlaceName = record.previousPlaceName
        newPlaceName = record.newPlaceName
        reason = record.reason
        acceptedAt = record.acceptedAt
        activity = activityEntity
    }
}
