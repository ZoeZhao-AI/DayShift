import Foundation

/// What the widget shows at one moment (Section 6.2), built only from saved
/// plans and checks (6.1). The widget builds one for each timeline date, so
/// statuses move on (In progress, Done) without the app running.
public struct WidgetSnapshot: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// The next plan that hasn't finished, and up to two after it.
        case plans(next: PlanLine, following: [PlanLine])
        /// "Your day is clear." or "That's everything for today."
        case message(title: String, detail: String?)
    }

    /// One plan as the widget shows it.
    public struct PlanLine: Equatable, Sendable {
        public let planID: UUID
        public let title: String
        /// e.g. "11:00 am".
        public let timeText: String
        /// The place's name, or "Online".
        public let placeText: String
        public let status: PlanDisplayStatus
        /// The first problem, when the plan needs attention.
        public let reason: String?
        /// e.g. "Leave by 12:35 pm", for an upcoming in-person plan.
        public let leaveByText: String?

        public init(
            planID: UUID,
            title: String,
            timeText: String,
            placeText: String,
            status: PlanDisplayStatus,
            reason: String?,
            leaveByText: String?
        ) {
            self.planID = planID
            self.title = title
            self.timeText = timeText
            self.placeText = placeText
            self.status = status
            self.reason = reason
            self.leaveByText = leaveByText
        }
    }

    public init(content: Content, comingUp: ComingUpDay? = nil) {
        self.content = content
        self.comingUp = comingUp
    }

    /// The first day from tomorrow to 7 days after today that has plans,
    /// with its first plans by time.
    private static func comingUpDay(from upcoming: [PlannedActivity], now: Date, calendar: Calendar) -> ComingUpDay? {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let afterLastDay = calendar.date(byAdding: .day, value: comingUpDays + 1, to: today)
        else { return nil }
        let later = upcoming
            .filter { $0.status != .cancelled && $0.start >= tomorrow && $0.start < afterLastDay }
            .sorted { $0.start < $1.start }
        guard let first = later.first else { return nil }

        let thatDay = later.filter { calendar.isDate($0.start, inSameDayAs: first.start) }
        let lines = thatDay.prefix(comingUpLimit).map { plan in
            ComingUpLine(
                planID: plan.id,
                title: plan.title,
                symbolName: ActivityCatalogue.type(withID: plan.typeID)?.symbolName ?? "calendar",
                timeText: TimeText.time(plan.start, calendar: calendar),
                placeText: plan.place?.name ?? "Online"
            )
        }
        return ComingUpDay(
            dayText: calendar.isDate(first.start, inSameDayAs: tomorrow) ? "Tomorrow" : TimeText.day(first.start, calendar: calendar),
            lines: Array(lines),
            moreCount: thatDay.count - lines.count
        )
    }

    /// The next day with plans, shown below "Your day is clear." or
    /// "That's everything for today." (6.2).
    public struct ComingUpDay: Equatable, Sendable {
        /// "Tomorrow", or e.g. "Saturday 10 Oct".
        public let dayText: String
        /// That day's first plans by time, up to `comingUpLimit`. Small shows the first.
        public let lines: [ComingUpLine]
        /// That day's other plans, shown as "+N more".
        public let moreCount: Int

        public init(dayText: String, lines: [ComingUpLine], moreCount: Int) {
            self.dayText = dayText
            self.lines = lines
            self.moreCount = moreCount
        }
    }

    /// One plan coming up. It has no status: future plans are checked on the day.
    public struct ComingUpLine: Equatable, Sendable {
        public let planID: UUID
        public let title: String
        /// The activity's SF Symbol, e.g. "figure.run".
        public let symbolName: String
        /// e.g. "7:00 am".
        public let timeText: String
        /// The place's name, or "Online".
        public let placeText: String

        public init(planID: UUID, title: String, symbolName: String, timeText: String, placeText: String) {
            self.planID = planID
            self.title = title
            self.symbolName = symbolName
            self.timeText = timeText
            self.placeText = placeText
        }
    }

    /// Medium shows the next plan and this many after it.
    public static let followingCount = 2
    /// How many days after today the coming-up plans can be, as on Today.
    public static let comingUpDays = 7
    /// Medium shows this many plans of the coming-up day.
    public static let comingUpLimit = 2

    public let content: Content
    /// Only with a message; nil when nothing is planned in the next 7 days.
    public let comingUp: ComingUpDay?

    /// - Parameters:
    ///   - plans: today's plans; cancelled ones are left out.
    ///   - upcoming: plans on later days; the first day with plans within
    ///     the next 7 days is shown, and only when today has nothing left.
    ///   - checks: each plan's last saved check, by plan id.
    public init(
        plans: [PlannedActivity],
        upcoming: [PlannedActivity] = [],
        checks: [UUID: PlanCheck],
        now: Date,
        calendar: Calendar
    ) {
        let todaysPlans = plans
            .filter { $0.status != .cancelled }
            .sorted { $0.start < $1.start }
        guard !todaysPlans.isEmpty else {
            content = .message(title: "Your day is clear.", detail: "Plan an activity in DayShift.")
            comingUp = Self.comingUpDay(from: upcoming, now: now, calendar: calendar)
            return
        }

        let remaining = todaysPlans.filter { $0.end > now }
        guard let next = remaining.first else {
            content = .message(title: "That's everything for today.", detail: nil)
            comingUp = Self.comingUpDay(from: upcoming, now: now, calendar: calendar)
            return
        }
        comingUp = nil

        func line(for plan: PlannedActivity) -> PlanLine {
            let saved = checks[plan.id]
            let status = PlanDisplayStatus(plan: plan, check: saved, now: now, calendar: calendar)
            let shown = PlanDisplayStatus.shownCheck(of: plan, check: saved, now: now, calendar: calendar)
            var leaveByText: String?
            if let leaveBy = shown?.leaveBy, let travel = shown?.travel, travel.minutes > 0 {
                leaveByText = "Leave by \(TimeText.time(leaveBy, calendar: calendar))"
            }
            return PlanLine(
                planID: plan.id,
                title: plan.title,
                timeText: TimeText.time(plan.start, calendar: calendar),
                placeText: plan.place?.name ?? "Online",
                status: status,
                reason: status == .needsAttention
                    ? shown?.findings.first { $0.severity == .problem }?.message
                    : nil,
                leaveByText: leaveByText
            )
        }

        content = .plans(
            next: line(for: next),
            following: remaining.dropFirst().prefix(Self.followingCount).map(line(for:))
        )
    }

    /// When the widget should change: now, and each start and end still to
    /// come, sorted with no repeats (6.2: "an entry now and at each plan's
    /// start and end").
    public static func timelineDates(plans: [PlannedActivity], now: Date) -> [Date] {
        let later = plans
            .filter { $0.status != .cancelled }
            .flatMap { [$0.start, $0.end] }
            .filter { $0 > now }
        return [now] + Set(later).sorted()
    }
}
