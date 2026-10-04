import Foundation
@testable import DayShiftKit

/// In-memory preferences that behave like `CoreDataPreferencesRepository`,
/// and record what was saved. Set `errorToThrow` to make every call fail.
final class MockPreferencesRepository: PreferencesRepository {
    var errorToThrow: Error?

    private(set) var storedPreferences: ComfortPreferences?
    private(set) var savedPreferences: [ComfortPreferences] = []

    init(preferences: ComfortPreferences? = nil) {
        storedPreferences = preferences
    }

    func load() async throws -> ComfortPreferences {
        try throwIfNeeded()
        return storedPreferences ?? .default
    }

    func save(_ preferences: ComfortPreferences) async throws {
        try throwIfNeeded()
        storedPreferences = preferences
        savedPreferences.append(preferences)
    }

    private func throwIfNeeded() throws {
        if let errorToThrow { throw errorToThrow }
    }
}
