import DayShiftKit
import Foundation
import Observation

/// Plans a new activity or edits one (Section 7.3, PlanEditor). Saving goes
/// through PlanActivityUseCase; its errors are shown inline, and "Save plan"
/// stays disabled until Lin changes something.
@MainActor
@Observable
final class PlanEditorViewModel {
    let activityTypes = ActivityCatalogue.all
    let isEditing: Bool

    var selectedTypeID: String {
        didSet {
            guard selectedTypeID != oldValue else { return }
            choosePlaceForSelectedType()
            changed()
        }
    }
    /// nil when the plan is online or no place is chosen yet.
    var selectedPlaceID: UUID? { didSet { changed() } }
    var isOnline = false { didSet { changed() } }
    var start: Date { didSet { changed() } }
    var durationMinutes: Int { didSet { changed() } }
    var canMove = false { didSet { changed() } }
    var windowStart: Date { didSet { changed() } }
    var windowEnd: Date { didSet { changed() } }
    var canChangePlace = false { didSet { changed() } }

    private(set) var savedPlaces: [Place] = []
    private(set) var inlineError: ErrorMessage?
    private(set) var isSaving = false
    /// The plan as saved, after `save()` succeeds.
    private(set) var savedPlan: PlannedActivity?

    private let existing: PlannedActivity?
    private let planActivity: PlanActivityUseCase
    private let places: PlaceRepository
    private let calendar: Calendar

    init(
        editing existing: PlannedActivity? = nil,
        planActivity: PlanActivityUseCase,
        places: PlaceRepository,
        calendar: Calendar,
        now: Date = Date()
    ) {
        self.existing = existing
        self.planActivity = planActivity
        self.places = places
        self.calendar = calendar
        isEditing = existing != nil

        if let existing {
            selectedTypeID = existing.typeID
            selectedPlaceID = existing.place?.id
            isOnline = existing.mode == .online
            start = existing.start
            durationMinutes = existing.durationMinutes
            canMove = existing.flexibility.movableWindow != nil
            windowStart = existing.flexibility.movableWindow?.start ?? existing.start.addingTimeInterval(-3600)
            windowEnd = existing.flexibility.movableWindow?.end ?? existing.end.addingTimeInterval(3600)
            canChangePlace = existing.flexibility.allowsPlaceChange
        } else {
            let start = Self.nextHalfHour(after: now, calendar: calendar)
            selectedTypeID = ActivityCatalogue.all[0].id
            self.start = start
            durationMinutes = 60
            windowStart = start.addingTimeInterval(-3600)
            windowEnd = start.addingTimeInterval(2 * 3600)
        }
    }

    // MARK: Derived

    var selectedType: ActivityType? {
        ActivityCatalogue.type(withID: selectedTypeID)
    }

    /// Lin's places that suit the chosen activity.
    var suitablePlaces: [Place] {
        guard let selectedType else { return savedPlaces }
        return savedPlaces.filter { selectedType.suitablePlaceKinds.contains($0.kind) }
    }

    var canBeOnline: Bool {
        selectedType?.canBeOnline ?? false
    }

    /// e.g. "Only places that suit Walk are shown. Online isn't offered for this activity."
    var placeNote: String {
        let name = selectedType?.name ?? "this activity"
        if suitablePlaces.isEmpty && !canBeOnline {
            return "None of your places suit \(name). Add one, then plan it here."
        }
        return "Only places that suit \(name) are shown."
            + (canBeOnline ? "" : " Online isn't offered for this activity.")
    }

    /// Disabled while an inline error is shown (7.4), while saving, or until a
    /// place (or Online) is chosen.
    var canSave: Bool {
        inlineError == nil && !isSaving && (isOnline || selectedPlaceID != nil)
    }

    var title: String {
        isEditing ? "Edit plan" : "Plan an activity"
    }

    // MARK: Actions

    func load() async {
        do {
            savedPlaces = try await places.allPlaces()
            if !isEditing { choosePlaceForSelectedType() }
        } catch {
            inlineError = ErrorMessage(error)
        }
    }

    /// Saves through PlanActivityUseCase. Returns true when the plan is saved.
    func save(now: Date = Date()) async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let plan = try makePlan()
            try await planActivity.execute(plan, now: now)
            savedPlan = plan
            return true
        } catch {
            inlineError = message(for: error)
            return false
        }
    }

    // MARK: Helpers

    private func changed() {
        inlineError = nil
    }

    private func choosePlaceForSelectedType() {
        if let selectedPlaceID, suitablePlaces.contains(where: { $0.id == selectedPlaceID }) {
            return
        }
        selectedPlaceID = suitablePlaces.first?.id
        isOnline = selectedPlaceID == nil && canBeOnline
    }

    private func makePlan() throws -> PlannedActivity {
        let place = isOnline ? nil : savedPlaces.first { $0.id == selectedPlaceID }
        let movableWindow: DateInterval?
        if canMove {
            let windowStart = sameDay(windowStart, as: start)
            let windowEnd = sameDay(windowEnd, as: start)
            guard windowEnd > windowStart else { throw EditorError.windowEndsBeforeItStarts }
            movableWindow = DateInterval(start: windowStart, end: windowEnd)
        } else {
            movableWindow = nil
        }
        let keepsTitle = existing?.typeID == selectedTypeID
        return try PlannedActivity(
            id: existing?.id ?? UUID(),
            typeID: selectedTypeID,
            title: keepsTitle ? (existing?.title ?? "") : (selectedType?.name ?? "Plan"),
            start: start,
            durationMinutes: durationMinutes,
            place: place,
            mode: isOnline ? .online : .inPerson,
            flexibility: ActivityFlexibility(
                movableWindow: movableWindow,
                allowsPlaceChange: !isOnline && canChangePlace
            ),
            status: existing?.status ?? .planned
        )
    }

    /// The time of day of `time`, on the day of `day`.
    private func sameDay(_ time: Date, as day: Date) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? time
    }

    private enum EditorError: Error {
        case windowEndsBeforeItStarts
    }

    /// Use-case errors say what went wrong themselves; domain errors from the
    /// form are put into Lin's words here.
    private func message(for error: Error) -> ErrorMessage {
        switch error {
        case EditorError.windowEndsBeforeItStarts:
            return ErrorMessage(
                title: "The time this plan can move between ends before it starts.",
                detail: "Choose a later end time, or turn off \"Can move\"."
            )
        case PlannedActivityError.movableWindowShorterThanPlan:
            return ErrorMessage(
                title: "The time this plan can move between is shorter than the plan.",
                detail: "Allow a longer time, or shorten the plan."
            )
        case PlannedActivityError.planOutsideMovableWindow:
            return ErrorMessage(
                title: "This plan isn't inside the time it can move between.",
                detail: "Change the times so they include the plan."
            )
        case PlannedActivityError.durationOutOfRange:
            return ErrorMessage(
                title: "A plan needs to last between 5 minutes and 12 hours.",
                detail: "Change how long it lasts."
            )
        default:
            return ErrorMessage(error)
        }
    }

    private static func nextHalfHour(after date: Date, calendar: Calendar) -> Date {
        let minute = calendar.component(.minute, from: date)
        let add = minute < 30 ? 30 - minute : 60 - minute
        let next = calendar.date(byAdding: .minute, value: add, to: date) ?? date
        return calendar.date(bySetting: .second, value: 0, of: next) ?? next
    }

    /// e.g. "45 min", "1 hr 30 min", "4 hr".
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }
}

/// Lets Today present the editor with `.sheet(item:)`.
extension PlanEditorViewModel: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}
