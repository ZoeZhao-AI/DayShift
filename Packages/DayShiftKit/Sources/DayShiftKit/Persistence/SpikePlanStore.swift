import CoreData
import Foundation
import os

/// Temporary store for the shared-store spike (Section 9, Step 2).
/// Proves the app can save a plan the widget can read. Replaced by
/// ActivityRepository in feature/repositories.
public final class SpikePlanStore {
    private static let logger = Logger(
        subsystem: "com.utsstudent.zhaoziying.DayShift",
        category: "SharedStore"
    )

    private let stack: CoreDataStack

    public init(appGroupIdentifier: String = AppGroup.identifier) throws {
        stack = try CoreDataStack(appGroupIdentifier: appGroupIdentifier)
    }

    /// Saves a plan with the given title, starting now.
    public func saveSamplePlan(title: String) throws {
        let context = stack.container.newBackgroundContext()
        try context.performAndWait {
            let plan = ActivityEntity(context: context)
            plan.id = UUID()
            plan.title = title
            plan.start = Date()
            try context.save()
        }
    }

    /// Title of the plan with the latest start, or nil if there are no plans
    /// or the store can't be read.
    public func latestPlanTitle() -> String? {
        let context = stack.container.newBackgroundContext()
        return context.performAndWait {
            let request = ActivityEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "start", ascending: false)]
            request.fetchLimit = 1
            do {
                return try context.fetch(request).first?.title
            } catch {
                Self.logger.error("Couldn't read the latest plan: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
    }
}
