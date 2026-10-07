import DayShiftKit
import Foundation
import Observation

/// Adds or edits a place (Section 7.3, PlaceEditor and PlaceEditorNew).
/// An address field replaces the prototype's Apple Maps search; saving goes
/// through SavePlaceUseCase, and its errors show inline.
@MainActor
@Observable
final class PlaceEditorViewModel {
    enum HoursChoice: String, CaseIterable, Identifiable {
        case alwaysOpen = "Always open"
        case set = "Set hours"
        case notSure = "Not sure"
        var id: String { rawValue }
    }

    let kinds = PlaceKind.allCases
    let isEditing: Bool

    var name: String { didSet { changed() } }
    var address: String { didSet { changed() } }
    var kind: PlaceKind {
        didSet {
            guard kind != oldValue else { return }
            if !isEditing { applyDefaults(for: kind) }
            changed()
        }
    }
    var isIndoor: Bool {
        didSet {
            if !isIndoor { isCooled = false }
            changed()
        }
    }
    var isCooled: Bool { didSet { changed() } }
    var heatLimitC: Double { didSet { changed() } }
    var hoursChoice: HoursChoice {
        didSet {
            hoursAreTypical = false
            changed()
        }
    }
    var opensAt: Date { didSet { hoursEdited() } }
    var closesAt: Date { didSet { hoursEdited() } }

    /// True while the hours are the kind's typical hours, not yet changed.
    private(set) var hoursAreTypical = false
    private(set) var inlineError: ErrorMessage?
    private(set) var isSaving = false
    /// e.g. "Newtown", from the saved place; filled in from the address when saving.
    private(set) var area: String?

    private let existing: Place?
    private let savePlace: SavePlaceUseCase
    private let calendar: Calendar

    init(editing place: Place? = nil, savePlace: SavePlaceUseCase, calendar: Calendar) {
        existing = place
        isEditing = place != nil
        self.savePlace = savePlace
        self.calendar = calendar

        let kind = place?.kind ?? .home
        name = place?.name ?? ""
        address = place?.address ?? ""
        self.kind = kind
        area = place?.suburb
        isIndoor = place?.isIndoor ?? kind.defaultIsIndoor
        isCooled = place?.isCooled ?? kind.defaultIsCooled
        heatLimitC = place?.uncooledHeatLimitC ?? Place.defaultUncooledHeatLimitC

        let day = calendar.startOfDay(for: Date())
        if let place {
            if place.isAlwaysOpen {
                hoursChoice = .alwaysOpen
            } else if place.openingHours != nil {
                hoursChoice = .set
            } else {
                hoursChoice = .notSure
            }
            opensAt = day.addingTimeInterval(TimeInterval((place.openingHours?.opensAt ?? 9 * 60) * 60))
            closesAt = day.addingTimeInterval(TimeInterval((place.openingHours?.closesAt ?? 17 * 60) * 60))
        } else {
            hoursChoice = .alwaysOpen
            opensAt = day.addingTimeInterval(9 * 3600)
            closesAt = day.addingTimeInterval(17 * 3600)
            applyDefaults(for: kind)
        }
    }

    var title: String { isEditing ? name : "New place" }

    /// The heat-limit row shows only for an indoor place without AC (PlaceEditorNew rule).
    var showsHeatLimit: Bool { isIndoor && !isCooled }

    /// "Typical for libraries: 10 am to 8 pm" while the pre-filled hours are unchanged.
    var typicalHoursNote: String? {
        guard hoursAreTypical, case let .hours(opens, closes) = kind.typicalOpeningHours else { return nil }
        return "Typical for \(kind.pluralName): \(TimeText.shortTime(minutesAfterMidnight: opens)) to \(TimeText.shortTime(minutesAfterMidnight: closes))"
    }

    var usualBusyTimes: String { kind.usualBusyTimes }

    var canSave: Bool {
        inlineError == nil && !isSaving
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Saves through SavePlaceUseCase. Returns true when the place is saved.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await savePlace.execute(PlaceDraft(
                id: existing?.id,
                name: name,
                kind: kind,
                address: address,
                isIndoor: isIndoor,
                isCooled: isIndoor && isCooled,
                uncooledHeatLimitC: showsHeatLimit ? heatLimitC : nil,
                isAlwaysOpen: hoursChoice == .alwaysOpen,
                openingHours: try openingHours()
            ))
            area = saved.suburb
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

    private func hoursEdited() {
        hoursAreTypical = false
        changed()
    }

    /// A new place starts from its kind: indoor, AC and typical hours,
    /// marked "Check and edit if different".
    private func applyDefaults(for kind: PlaceKind) {
        isIndoor = kind.defaultIsIndoor
        isCooled = kind.defaultIsCooled
        let day = calendar.startOfDay(for: Date())
        switch kind.typicalOpeningHours {
        case .alwaysOpen:
            hoursChoice = .alwaysOpen
        case let .hours(opens, closes):
            hoursChoice = .set
            opensAt = day.addingTimeInterval(TimeInterval(opens * 60))
            closesAt = day.addingTimeInterval(TimeInterval(closes * 60))
        case .unknown:
            hoursChoice = .notSure
        }
        hoursAreTypical = true
    }

    private enum EditorError: Error {
        case closesBeforeOpening
    }

    private func openingHours() throws -> OpeningHours? {
        guard hoursChoice == .set else { return nil }
        let opens = minutesAfterMidnight(opensAt)
        let closes = minutesAfterMidnight(closesAt)
        do {
            return try OpeningHours(opensAt: opens, closesAt: closes, closedWeekdays: [])
        } catch {
            throw EditorError.closesBeforeOpening
        }
    }

    private func minutesAfterMidnight(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func message(for error: Error) -> ErrorMessage {
        if case EditorError.closesBeforeOpening = error {
            return ErrorMessage(title: "The closing time is before the opening time.", detail: "Choose a later closing time.")
        }
        return ErrorMessage(error)
    }
}

/// Lets My Places present the editor with `.sheet(item:)`.
extension PlaceEditorViewModel: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}
