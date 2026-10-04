import CoreData
import Foundation

extension ActivityEntity {
    private static let entityName = "ActivityEntity"

    /// The stored plan. Runs the same checks as `PlannedActivity.init`.
    func plannedActivity() throws -> PlannedActivity {
        let movableWindow: DateInterval?
        switch (movableWindowStart, movableWindowEnd) {
        case let (windowStart?, windowEnd?) where windowEnd >= windowStart:
            movableWindow = DateInterval(start: windowStart, end: windowEnd)
        case (nil, nil):
            movableWindow = nil
        default:
            throw PersistenceMappingError.invalidValue(entity: Self.entityName, attribute: "movableWindow")
        }

        return try PlannedActivity(
            id: id,
            typeID: typeID,
            title: title,
            start: start,
            durationMinutes: Int(durationMinutes),
            place: place?.place(),
            mode: PersistenceMapping.decodeRaw(
                modeRaw, as: ActivityMode.self, entity: Self.entityName, attribute: "modeRaw"
            ),
            flexibility: ActivityFlexibility(
                movableWindow: movableWindow,
                allowsPlaceChange: allowsPlaceChange
            ),
            status: PersistenceMapping.decodeRaw(
                statusRaw, as: PlanStatus.self, entity: Self.entityName, attribute: "statusRaw"
            )
        )
    }

    /// Copies the plan's own fields. The saved check and notified reasons are left as they are.
    /// - Parameter placeEntity: the stored place with the same id as `plan.place`.
    func update(from plan: PlannedActivity, placeEntity: PlaceEntity?) throws {
        guard placeEntity?.id == plan.place?.id else {
            throw PersistenceMappingError.mismatchedRelationship(entity: Self.entityName, relationship: "place")
        }
        id = plan.id
        typeID = plan.typeID
        title = plan.title
        modeRaw = plan.mode.rawValue
        statusRaw = plan.status.rawValue
        start = plan.start
        end = plan.end
        durationMinutes = try PersistenceMapping.int16(
            plan.durationMinutes, entity: Self.entityName, attribute: "durationMinutes"
        )
        movableWindowStart = plan.flexibility.movableWindow?.start
        movableWindowEnd = plan.flexibility.movableWindow?.end
        allowsPlaceChange = plan.flexibility.allowsPlaceChange
        place = placeEntity
    }

    /// The last saved check, or nil if the plan hasn't been checked yet.
    func planCheck() throws -> PlanCheck? {
        guard let checkedAt else { return nil }

        let travel: TravelEstimate?
        switch (travelMinutes, travelModeRaw) {
        case let (minutes?, modeRaw?):
            travel = TravelEstimate(
                minutes: minutes.intValue,
                mode: try PersistenceMapping.decodeRaw(
                    modeRaw, as: TravelMode.self, entity: Self.entityName, attribute: "travelModeRaw"
                )
            )
        case (nil, nil):
            travel = nil
        default:
            throw PersistenceMappingError.invalidValue(entity: Self.entityName, attribute: "travelMinutes/travelModeRaw")
        }

        let findings = try findingsData.map {
            try JSONDecoder().decode([PlanFinding].self, from: $0)
        } ?? []

        return PlanCheck(
            planID: id,
            checkedAt: checkedAt,
            leaveBy: leaveBy,
            travel: travel,
            findings: findings
        )
    }

    /// Saves the check on the plan, replacing any earlier check.
    func apply(_ check: PlanCheck) throws {
        guard check.planID == id else {
            throw PersistenceMappingError.mismatchedRelationship(entity: Self.entityName, relationship: "planCheck")
        }
        checkStatusRaw = check.overallStatus.rawValue
        checkSummary = check.findings.first { $0.severity == .problem }?.message
        checkedAt = check.checkedAt
        leaveBy = check.leaveBy
        if let travel = check.travel {
            travelMinutes = NSNumber(value: try PersistenceMapping.int16(
                travel.minutes, entity: Self.entityName, attribute: "travelMinutes"
            ))
            travelModeRaw = travel.mode.rawValue
        } else {
            travelMinutes = nil
            travelModeRaw = nil
        }
        findingsData = try JSONEncoder().encode(check.findings)
    }

    /// Reasons Lin has already been alerted about.
    var notifiedReasons: Set<String> {
        get { PersistenceMapping.keys(from: notifiedReasonKeys) }
        set { notifiedReasonKeys = PersistenceMapping.joinedKeys(newValue) }
    }
}
