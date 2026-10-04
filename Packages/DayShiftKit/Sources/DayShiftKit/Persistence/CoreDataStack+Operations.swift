import CoreData
import Foundation

extension CoreDataStack {
    /// Runs `body` on a new background context. Errors other than
    /// `PersistenceError` become `.couldNotRead`.
    func read<Result>(_ body: @escaping (NSManagedObjectContext) throws -> Result) async throws -> Result {
        let context = newBackgroundContext()
        do {
            return try await context.perform { try body(context) }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.couldNotRead(underlying: error)
        }
    }

    /// Runs `body` on a new background context and saves once at the end,
    /// so every change in `body` is saved together or not at all. Errors
    /// other than `PersistenceError` become `.couldNotSave`.
    func write(_ body: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let context = newBackgroundContext()
        do {
            try await context.perform {
                do {
                    try body(context)
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    context.rollback()
                    throw error
                }
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.couldNotSave(underlying: error)
        }
    }

    private func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}

extension NSManagedObjectContext {
    /// The stored object with this id, or nil.
    func first<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>, id: UUID) throws -> Entity? {
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try fetch(request).first
    }
}
