import CoreData
import Foundation

/// Why the shared store could not be opened.
public enum CoreDataStackError: LocalizedError {
    case appGroupUnavailable(identifier: String)
    case modelNotFound
    case storeFailedToLoad(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "DayShift can't open its shared storage."
        case .modelNotFound:
            return "DayShift's storage is damaged."
        case .storeFailedToLoad:
            return "DayShift couldn't open your saved plans."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "Check that the App Group \(identifier) is enabled for this target."
        case .modelNotFound, .storeFailedToLoad:
            return "Please reinstall DayShift."
        }
    }
}

/// Opens the DayShift Core Data store in the App Group container,
/// so the app and its extensions read and write the same SQLite file.
public final class CoreDataStack {
    static let modelName = "DayShift"

    /// Loaded once per process; loading the same model twice confuses Core Data.
    private static let model: NSManagedObjectModel? = {
        guard let url = Bundle.module.url(forResource: modelName, withExtension: "momd") else {
            return nil
        }
        return NSManagedObjectModel(contentsOf: url)
    }()

    let container: NSPersistentContainer

    public init(appGroupIdentifier: String = AppGroup.identifier) throws {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw CoreDataStackError.appGroupUnavailable(identifier: appGroupIdentifier)
        }
        guard let model = Self.model else {
            throw CoreDataStackError.modelNotFound
        }

        let container = NSPersistentContainer(name: Self.modelName, managedObjectModel: model)
        let description = NSPersistentStoreDescription(
            url: groupURL.appendingPathComponent("\(Self.modelName).sqlite")
        )
        description.shouldAddStoreAsynchronously = false
        // The app and the extensions write to the same store; history lets
        // the app pick up their changes when it becomes active.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw CoreDataStackError.storeFailedToLoad(underlying: loadError)
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        self.container = container
    }
}
