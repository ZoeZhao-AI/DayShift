import CoreData
import Foundation

/// Places stored in the shared Core Data store.
public final class CoreDataPlaceRepository: PlaceRepository {
    private let stack: CoreDataStack

    public init(stack: CoreDataStack) {
        self.stack = stack
    }

    /// Sorted by name.
    public func allPlaces() async throws -> [Place] {
        try await stack.read { context in
            let request = PlaceEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            ]
            return try context.fetch(request).map { try $0.place() }
        }
    }

    /// Ignores case and surrounding spaces, so "home " finds "Home".
    public func place(named name: String) async throws -> Place? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await stack.read { context in
            let request = PlaceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)
            request.fetchLimit = 1
            return try context.fetch(request).first?.place()
        }
    }

    public func save(_ place: Place) async throws {
        try await stack.write { context in
            let entity = try context.first(PlaceEntity.fetchRequest(), id: place.id)
                ?? PlaceEntity(context: context)
            try entity.update(from: place)
        }
    }

    public func home() async throws -> Place? {
        try await stack.read { context in
            let request = PlaceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "kindRaw == %@", PlaceKind.home.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            request.fetchLimit = 1
            return try context.fetch(request).first?.place()
        }
    }
}
