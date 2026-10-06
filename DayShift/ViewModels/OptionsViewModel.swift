import DayShiftKit
import Foundation
import Observation

/// Options for one plan (Section 7.3, OptionsRun/Focus/Grocery/None).
/// Suggestions come from SuggestAlternativesUseCase; "Use this plan" goes
/// through AcceptAlternativeUseCase.
@MainActor
@Observable
final class OptionsViewModel {
    struct OptionCard: Identifiable {
        let id: UUID
        /// e.g. "Move to 5:30 pm · Enmore Park".
        let title: String
        let explanation: String
        let scheduleNote: String
        let isRecommended: Bool
        let option: AlternativePlan
    }

    private(set) var plan: PlannedActivity
    private(set) var status: PlanDisplayStatus
    /// The current plan's first problem, or "You don't need to change anything."
    private(set) var currentNote: String?
    private(set) var options: [OptionCard] = []
    /// No options at all, in Lin's words (e.g. noViableAlternative).
    private(set) var noResult: ErrorMessage?
    /// Why nothing fits, e.g. "Wind gusts 56–70 km/h all day, above your limit of 40 km/h."
    private(set) var noResultReasons: [String] = []
    /// A failed "Use this plan", shown above the options.
    private(set) var acceptError: ErrorMessage?
    private(set) var isLoading = false
    private(set) var isAccepting = false

    private let suggestAlternatives: SuggestAlternativesUseCase
    private let acceptAlternative: AcceptAlternativeUseCase
    private let activities: ActivityRepository
    private let calendar: Calendar

    init(
        plan: PlannedActivity,
        suggestAlternatives: SuggestAlternativesUseCase,
        acceptAlternative: AcceptAlternativeUseCase,
        activities: ActivityRepository,
        calendar: Calendar,
        now: Date = Date()
    ) {
        self.plan = plan
        self.suggestAlternatives = suggestAlternatives
        self.acceptAlternative = acceptAlternative
        self.activities = activities
        self.calendar = calendar
        status = PlanDisplayStatus(plan: plan, check: nil, now: now, calendar: calendar)
    }

    /// e.g. "Options for your run".
    var title: String {
        "Options for your \(plan.title.lowercased())"
    }

    /// e.g. "7:00 am · Enmore Park".
    var currentSummary: String {
        "\(TimeText.time(plan.start, calendar: calendar)) · \(plan.place?.name ?? "Online")"
    }

    /// "2 better options" when the plan needs attention, "Other good options" otherwise.
    var optionsHeading: String? {
        guard !options.isEmpty else { return nil }
        guard status == .needsAttention else { return "Other good options" }
        return options.count == 1 ? "1 better option" : "\(options.count) better options"
    }

    func load(now: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let check = try await activities.check(for: plan.id)
            status = PlanDisplayStatus(plan: plan, check: check, now: now, calendar: calendar)
            let shownCheck = PlanDisplayStatus.shownCheck(of: plan, check: check, now: now, calendar: calendar)
            currentNote = status == .needsAttention
                ? shownCheck?.findings.first { $0.severity == .problem }?.message
                : "You don't need to change anything."

            let suggestions = try await suggestAlternatives.execute(for: plan, now: now)
            options = suggestions.options.enumerated().map { index, option in
                OptionCard(
                    id: option.id,
                    title: option.title(for: plan, calendar: calendar),
                    explanation: option.explanation,
                    scheduleNote: option.scheduleNote,
                    isRecommended: index == 0 && status == .needsAttention,
                    option: option
                )
            }
            noResult = nil
            noResultReasons = []
        } catch {
            options = []
            noResult = message(for: error, now: now)
            noResultReasons = error as? SuggestAlternativesError == .noViableAlternative
                ? (try? await suggestAlternatives.reasonsWithoutOptions(for: plan, now: now)) ?? []
                : []
        }
    }

    /// The use case's wording says "today"; a plan on another day names its day,
    /// e.g. "No time or place tomorrow keeps this plan within your limits."
    private func message(for error: Error, now: Date) -> ErrorMessage {
        let message = ErrorMessage(error)
        guard error as? SuggestAlternativesError == .noViableAlternative,
              !calendar.isDate(plan.start, inSameDayAs: now)
        else { return message }
        return ErrorMessage(
            title: "No time or place \(dayPhrase(for: plan.start, now: now)) keeps this plan within your limits.",
            detail: message.detail
        )
    }

    /// "tomorrow", or e.g. "on Thursday 8 Oct".
    private func dayPhrase(for date: Date, now: Date) -> String {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        if let tomorrow, calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow"
        }
        return "on \(TimeText.day(date, calendar: calendar))"
    }

    /// Uses the option. Returns the toast for Today, e.g. "Your run is now at
    /// 5:30 pm.", or nil if it couldn't be used (the error is shown here).
    func use(_ card: OptionCard, now: Date = Date()) async -> String? {
        isAccepting = true
        defer { isAccepting = false }
        do {
            let changed = try await acceptAlternative.execute(card.option, now: now)
            acceptError = nil
            switch card.option.adjustment {
            case .shiftTime:
                return "Your \(changed.title.lowercased()) is now at \(TimeText.time(changed.start, calendar: calendar))."
            case .changePlace:
                return "\(changed.title) is now at \(changed.place?.name ?? "a new place")."
            }
        } catch {
            acceptError = ErrorMessage(error)
            return nil
        }
    }

}

/// Lets Plan Detail push Options as navigation state.
extension OptionsViewModel: Hashable {
    nonisolated static func == (lhs: OptionsViewModel, rhs: OptionsViewModel) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
