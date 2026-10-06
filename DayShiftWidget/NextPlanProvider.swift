import DayShiftKit
import Foundation
import os
import WidgetKit

struct NextPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    /// Shown while the widget loads and in the widget gallery.
    static let placeholder = NextPlanEntry(
        date: .now,
        snapshot: WidgetSnapshot(content: .plans(
            next: WidgetSnapshot.PlanLine(
                planID: UUID(), title: "Client call", timeText: "11:00 am", placeText: "Online",
                status: .looksGood, reason: nil, leaveByText: nil
            ),
            following: [
                WidgetSnapshot.PlanLine(
                    planID: UUID(), title: "Focus work", timeText: "1:00 pm", placeText: "Newtown Library",
                    status: .looksGood, reason: nil, leaveByText: "Leave by 12:35 pm"
                ),
                WidgetSnapshot.PlanLine(
                    planID: UUID(), title: "Grocery run", timeText: "5:30 pm", placeText: "Marrickville Metro",
                    status: .looksGood, reason: nil, leaveByText: "Leave by 5:20 pm"
                )
            ]
        ))
    )
}

/// Reads today's plans and their saved checks from the shared store (6.1)
/// and builds an entry now and at each plan's start and end (6.2). Never
/// calls the network; if the store can't be read, shows the empty state.
struct NextPlanProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.utsstudent.zhaoziying.DayShift", category: "SharedStore")

    func placeholder(in context: Context) -> NextPlanEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPlanEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let now = Date()
            let (plans, checks) = await savedPlans(on: now)
            completion(NextPlanEntry(date: now, snapshot: WidgetSnapshot(plans: plans, checks: checks, now: now, calendar: .current)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPlanEntry>) -> Void) {
        Task {
            let now = Date()
            let calendar = Calendar.current
            let (plans, checks) = await savedPlans(on: now)
            let dates = WidgetSnapshot.timelineDates(plans: plans, now: now)
            let entries = dates.map { date in
                NextPlanEntry(date: date, snapshot: WidgetSnapshot(plans: plans, checks: checks, now: date, calendar: calendar))
            }
            completion(Timeline(entries: entries, policy: Self.policy(for: dates, now: now, calendar: calendar)))
        }
    }

    /// `.atEnd` while plans are still to come (6.2). After the last one, wait
    /// until tomorrow rather than asking again straight away; the app reloads
    /// the widget whenever a plan changes.
    private static func policy(for dates: [Date], now: Date, calendar: Calendar) -> TimelineReloadPolicy {
        guard dates.count <= 1 else { return .atEnd }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        return tomorrow.map { .after($0) } ?? .atEnd
    }

    /// Today's plans and checks, or none if the shared store can't be read.
    private func savedPlans(on day: Date) async -> ([PlannedActivity], [UUID: PlanCheck]) {
        do {
            let repository = CoreDataActivityRepository(stack: try CoreDataStack())
            let plans = try await repository.plans(on: day)
            var checks: [UUID: PlanCheck] = [:]
            for plan in plans {
                checks[plan.id] = try? await repository.check(for: plan.id)
            }
            return (plans, checks)
        } catch {
            Self.logger.error("Couldn't read today's plans: \(String(describing: error), privacy: .public)")
            return ([], [:])
        }
    }
}
