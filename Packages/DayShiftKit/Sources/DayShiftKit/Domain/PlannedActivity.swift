import Foundation

/// A plan: one activity scheduled at a time, at a place or online.
public struct PlannedActivity: Identifiable, Hashable, Sendable {
    public static let durationRange = 5...720

    public let id: UUID
    public let typeID: String
    public let title: String
    public let start: Date
    public let durationMinutes: Int
    /// nil only when the plan is online.
    public let place: Place?
    public let mode: ActivityMode
    public let flexibility: ActivityFlexibility
    public let status: PlanStatus

    public init(
        id: UUID = UUID(),
        typeID: String,
        title: String,
        start: Date,
        durationMinutes: Int,
        place: Place?,
        mode: ActivityMode,
        flexibility: ActivityFlexibility,
        status: PlanStatus = .planned
    ) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw PlannedActivityError.titleIsEmpty
        }
        guard Self.durationRange.contains(durationMinutes) else {
            throw PlannedActivityError.durationOutOfRange
        }
        switch (mode, place) {
        case (.online, .some):
            throw PlannedActivityError.onlinePlanHasPlace
        case (.inPerson, .none):
            throw PlannedActivityError.inPersonPlanHasNoPlace
        case (.online, .none), (.inPerson, .some):
            break
        }
        if let window = flexibility.movableWindow {
            let plan = DateInterval(start: start, duration: TimeInterval(durationMinutes * 60))
            guard window.duration >= plan.duration else {
                throw PlannedActivityError.movableWindowShorterThanPlan
            }
            guard window.start <= plan.start, plan.end <= window.end else {
                throw PlannedActivityError.planOutsideMovableWindow
            }
        }

        self.id = id
        self.typeID = typeID
        self.title = trimmedTitle
        self.start = start
        self.durationMinutes = durationMinutes
        self.place = place
        self.mode = mode
        self.flexibility = flexibility
        self.status = status
    }

    public var end: Date {
        start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    public var interval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

public enum PlannedActivityError: Error, Equatable {
    case titleIsEmpty
    case durationOutOfRange
    case onlinePlanHasPlace
    case inPersonPlanHasNoPlace
    case movableWindowShorterThanPlan
    case planOutsideMovableWindow
}
