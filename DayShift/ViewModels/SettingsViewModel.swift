import DayShiftKit
import Foundation
import Observation

/// Lin's limits, her day and alerts (Section 7.3, Settings). Current values
/// are read through PreferencesRepository (1.3); saving goes through
/// UpdateComfortPreferencesUseCase, then today's plans are checked again (3.5).
@MainActor
@Observable
final class SettingsViewModel {
    enum AlertsState: Equatable {
        case allowed
        case off
        case notAskedYet
    }

    /// The values being edited; saved with `save()`.
    var draft: ComfortPreferencesDraft {
        didSet { saveError = nil; savedMessage = nil }
    }
    private(set) var saved: ComfortPreferencesDraft
    private(set) var saveError: ErrorMessage?
    private(set) var savedMessage: String?
    private(set) var isSaving = false
    private(set) var alerts: AlertsState = .notAskedYet

    private let preferences: PreferencesRepository
    private let updatePreferences: UpdateComfortPreferencesUseCase
    private let checkUpcomingPlans: CheckUpcomingPlansUseCase
    private let alertsStatus: AlertsStatusChecking
    private let calendar: Calendar

    init(
        preferences: PreferencesRepository,
        updatePreferences: UpdateComfortPreferencesUseCase,
        checkUpcomingPlans: CheckUpcomingPlansUseCase,
        alertsStatus: AlertsStatusChecking,
        calendar: Calendar
    ) {
        self.preferences = preferences
        self.updatePreferences = updatePreferences
        self.checkUpcomingPlans = checkUpcomingPlans
        self.alertsStatus = alertsStatus
        self.calendar = calendar
        draft = ComfortPreferencesDraft(.default)
        saved = ComfortPreferencesDraft(.default)
    }

    var hasChanges: Bool { draft != saved }

    func load() async {
        do {
            let current = ComfortPreferencesDraft(try await preferences.load())
            saved = current
            draft = current
        } catch {
            saveError = ErrorMessage(error)
        }
        await loadAlerts()
    }

    func loadAlerts() async {
        if await alertsStatus.hasNotBeenAsked() {
            alerts = .notAskedYet
        } else if await alertsStatus.alertsAreOff() {
            alerts = .off
        } else {
            alerts = .allowed
        }
    }

    func allowAlerts() async {
        _ = await alertsStatus.askForPermission()
        await loadAlerts()
    }

    /// Saves through UpdateComfortPreferencesUseCase (which reloads the
    /// widget), then checks today's plans against the new limits.
    func save(now: Date = Date()) async {
        guard hasChanges, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let savedPreferences = try await updatePreferences.execute(draft)
            saved = ComfortPreferencesDraft(savedPreferences)
            draft = saved
            _ = try? await checkUpcomingPlans.execute(now: now)
            savedMessage = "Saved. Today's plans were checked against your new limits."
        } catch {
            saveError = ErrorMessage(error)
        }
    }

    func discardChanges() {
        draft = saved
    }

    // MARK: Planning hours as times of day

    var earliestTime: Date {
        get { time(minutes: draft.earliestPlanTime) }
        set { draft.earliestPlanTime = minutes(newValue) }
    }

    var latestTime: Date {
        get { time(minutes: draft.latestPlanTime) }
        set { draft.latestPlanTime = minutes(newValue) }
    }

    private func time(minutes: Int) -> Date {
        calendar.startOfDay(for: Date()).addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func minutes(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func name(of mode: TravelMode) -> String {
        switch mode {
        case .walking: return "Walking"
        case .publicTransport: return "Public transport"
        case .driving: return "Driving"
        }
    }
}
