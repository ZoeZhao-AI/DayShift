import CoreData
import Foundation

/// Lin's comfort preferences, stored as a single row in the shared Core Data store.
public final class CoreDataPreferencesRepository: PreferencesRepository {
    private let stack: CoreDataStack

    public init(stack: CoreDataStack) {
        self.stack = stack
    }

    public func load() async throws -> ComfortPreferences {
        try await stack.read { context in
            let request = PreferencesEntity.fetchRequest()
            request.fetchLimit = 1
            return try context.fetch(request).first?.comfortPreferences() ?? .default
        }
    }

    /// Updates the single row, creating it the first time.
    public func save(_ preferences: ComfortPreferences) async throws {
        try await stack.write { context in
            let request = PreferencesEntity.fetchRequest()
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? PreferencesEntity(context: context)
            try entity.update(from: preferences)
        }
    }
}
