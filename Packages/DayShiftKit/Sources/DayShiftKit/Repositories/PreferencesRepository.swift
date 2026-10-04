import Foundation

/// Reads and saves Lin's comfort preferences.
public protocol PreferencesRepository {
    /// The saved preferences, or `ComfortPreferences.default` if none are saved.
    func load() async throws -> ComfortPreferences

    func save(_ preferences: ComfortPreferences) async throws
}
