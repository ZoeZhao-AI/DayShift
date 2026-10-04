import CoreData
import Foundation

/// Plans stored in the shared Core Data store.
public final class CoreDataActivityRepository: ActivityRepository {
    private let stack: CoreDataStack
    private let calendar: Calendar

    public init(stack: CoreDataStack, calendar: Calendar = .current) {
        self.stack = stack
        self.calendar = calendar
    }

    public func plans(on day: Date) async throws -> [PlannedActivity] {
        try await plans(matching: ActivityQuery.plans(on: day, calendar: calendar))
    }

    public func checkablePlans(on day: Date, now: Date) async throws -> [PlannedActivity] {
        try await plans(matching: ActivityQuery.checkablePlans(on: day, now: now, calendar: calendar))
    }

    public func plans(overlapping interval: DateInterval, excluding ids: Set<UUID>) async throws -> [PlannedActivity] {
        try await plans(matching: ActivityQuery.plans(overlapping: interval, excluding: ids))
    }

    public func save(_ plan: PlannedActivity) async throws {
        try await stack.write { context in
            let entity = try context.first(ActivityEntity.fetchRequest(), id: plan.id)
                ?? ActivityEntity(context: context)
            try entity.update(from: plan, placeEntity: Self.placeEntity(for: plan, in: context))
        }
    }

    /// Deleting a plan that no longer exists does nothing.
    public func delete(id: UUID) async throws {
        try await stack.write { context in
            if let entity = try context.first(ActivityEntity.fetchRequest(), id: id) {
                context.delete(entity)
            }
        }
    }

    public func saveCheck(_ check: PlanCheck) async throws {
        try await stack.write { context in
            try Self.planEntity(id: check.planID, in: context).apply(check)
        }
    }

    public func check(for planID: UUID) async throws -> PlanCheck? {
        try await stack.read { context in
            try Self.planEntity(id: planID, in: context).planCheck()
        }
    }

    /// Adds to the reasons already recorded, so each reason is alerted once.
    public func markNotified(planID: UUID, reasonKeys: Set<String>) async throws {
        try await stack.write { context in
            let entity = try Self.planEntity(id: planID, in: context)
            entity.notifiedReasons = entity.notifiedReasons.union(reasonKeys)
        }
    }

    public func notifiedReasonKeys(planID: UUID) async throws -> Set<String> {
        try await stack.read { context in
            try Self.planEntity(id: planID, in: context).notifiedReasons
        }
    }

    /// Saves every changed plan and every record in one save: all or nothing.
    public func applyAdjustment(changedPlans: [PlannedActivity], records: [AdjustmentRecord]) async throws {
        try await stack.write { context in
            for plan in changedPlans {
                try Self.planEntity(id: plan.id, in: context)
                    .update(from: plan, placeEntity: Self.placeEntity(for: plan, in: context))
            }
            for record in records {
                try AdjustmentRecordEntity(context: context)
                    .update(from: record, activityEntity: Self.planEntity(id: record.planID, in: context))
            }
        }
    }

    private func plans(matching predicate: NSPredicate) async throws -> [PlannedActivity] {
        try await stack.read { context in
            let request = ActivityEntity.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "start", ascending: true)]
            return try context.fetch(request).map { try $0.plannedActivity() }
        }
    }

    private static func planEntity(id: UUID, in context: NSManagedObjectContext) throws -> ActivityEntity {
        guard let entity = try context.first(ActivityEntity.fetchRequest(), id: id) else {
            throw PersistenceError.planNotFound
        }
        return entity
    }

    /// The stored place of an in-person plan; nil for an online plan.
    private static func placeEntity(for plan: PlannedActivity, in context: NSManagedObjectContext) throws -> PlaceEntity? {
        guard let place = plan.place else { return nil }
        guard let entity = try context.first(PlaceEntity.fetchRequest(), id: place.id) else {
            throw PersistenceError.placeNotFound
        }
        return entity
    }
}
