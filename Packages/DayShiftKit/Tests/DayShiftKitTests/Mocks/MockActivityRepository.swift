import Foundation
@testable import DayShiftKit

/// In-memory plans that behave like `CoreDataActivityRepository`, and record
/// what was saved. Set `errorToThrow` to make every call fail.
final class MockActivityRepository: ActivityRepository {
    var errorToThrow: Error?
    /// Makes only `applyAdjustment` fail, after the plans have been read.
    var applyAdjustmentErrorToThrow: Error?
    /// Makes `saveCheck` fail from this call on (1 = the first call), so a
    /// check can fail partway through a day.
    var saveCheckFailsFromCall: Int?
    var saveCheckErrorToThrow: Error = PersistenceError.couldNotSave(underlying: CocoaError(.fileWriteUnknown))
    private var saveCheckCalls = 0

    private(set) var storedPlans: [UUID: PlannedActivity]
    private(set) var storedChecks: [UUID: PlanCheck] = [:]
    private(set) var storedNotifiedReasons: [UUID: Set<String>] = [:]
    private(set) var storedRecords: [AdjustmentRecord] = []

    private(set) var savedPlans: [PlannedActivity] = []
    private(set) var deletedIDs: [UUID] = []
    private(set) var savedChecks: [PlanCheck] = []
    private(set) var appliedAdjustmentCount = 0

    private let calendar: Calendar

    init(plans: [PlannedActivity] = [], calendar: Calendar) {
        storedPlans = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
        self.calendar = calendar
    }

    func plans(on day: Date) async throws -> [PlannedActivity] {
        try throwIfNeeded()
        return sorted(storedPlans.values.filter {
            calendar.isDate($0.start, inSameDayAs: day) && $0.status != .cancelled
        })
    }

    func checkablePlans(on day: Date, now: Date) async throws -> [PlannedActivity] {
        try throwIfNeeded()
        return sorted(storedPlans.values.filter {
            calendar.isDate($0.start, inSameDayAs: day)
                && $0.start > now
                && ($0.status == .planned || $0.status == .adjusted)
        })
    }

    func plans(overlapping interval: DateInterval, excluding ids: Set<UUID>) async throws -> [PlannedActivity] {
        try throwIfNeeded()
        return sorted(storedPlans.values.filter {
            $0.start < interval.end && $0.end > interval.start
                && !ids.contains($0.id)
                && $0.status != .cancelled
        })
    }

    func save(_ plan: PlannedActivity) async throws {
        try throwIfNeeded()
        store(plan)
        savedPlans.append(plan)
    }

    func delete(id: UUID) async throws {
        try throwIfNeeded()
        storedPlans[id] = nil
        storedChecks[id] = nil
        storedNotifiedReasons[id] = nil
        storedRecords.removeAll { $0.planID == id }
        deletedIDs.append(id)
    }

    func saveCheck(_ check: PlanCheck) async throws {
        try throwIfNeeded()
        saveCheckCalls += 1
        if let failsFrom = saveCheckFailsFromCall, saveCheckCalls >= failsFrom {
            throw saveCheckErrorToThrow
        }
        try requirePlan(check.planID)
        storedChecks[check.planID] = check
        savedChecks.append(check)
    }

    func check(for planID: UUID) async throws -> PlanCheck? {
        try throwIfNeeded()
        try requirePlan(planID)
        return storedChecks[planID]
    }

    func markNotified(planID: UUID, reasonKeys: Set<String>) async throws {
        try throwIfNeeded()
        try requirePlan(planID)
        storedNotifiedReasons[planID, default: []].formUnion(reasonKeys)
    }

    func notifiedReasonKeys(planID: UUID) async throws -> Set<String> {
        try throwIfNeeded()
        try requirePlan(planID)
        return storedNotifiedReasons[planID] ?? []
    }

    /// All or nothing: checks every plan exists before changing anything.
    func applyAdjustment(changedPlans: [PlannedActivity], records: [AdjustmentRecord]) async throws {
        try throwIfNeeded()
        if let applyAdjustmentErrorToThrow { throw applyAdjustmentErrorToThrow }
        for id in changedPlans.map(\.id) + records.map(\.planID) {
            try requirePlan(id)
        }
        changedPlans.forEach(store)
        storedRecords.append(contentsOf: records)
        appliedAdjustmentCount += 1
    }

    /// Like the Core Data repository: a new start, duration or place clears
    /// the saved check and the notified reasons.
    private func store(_ plan: PlannedActivity) {
        if let previous = storedPlans[plan.id],
           previous.start != plan.start
            || previous.durationMinutes != plan.durationMinutes
            || previous.place?.id != plan.place?.id {
            storedChecks[plan.id] = nil
            storedNotifiedReasons[plan.id] = nil
        }
        storedPlans[plan.id] = plan
    }

    private func requirePlan(_ id: UUID) throws {
        guard storedPlans[id] != nil else { throw PersistenceError.planNotFound }
    }

    private func sorted(_ plans: some Sequence<PlannedActivity>) -> [PlannedActivity] {
        plans.sorted { $0.start < $1.start }
    }

    private func throwIfNeeded() throws {
        if let errorToThrow { throw errorToThrow }
    }
}
