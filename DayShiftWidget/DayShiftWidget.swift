//
//  DayShiftWidget.swift
//  DayShiftWidget
//
//  Created by Alex W on 3/10/2026.
//

import DayShiftKit
import os
import SwiftUI
import WidgetKit

/// Temporary widget for the shared-store spike (Section 9, Step 2):
/// shows the title of today's first plan, read through ActivityRepository.
/// Replaced by NextPlanWidget in Step 4.
struct Provider: TimelineProvider {
    private static let logger = Logger(
        subsystem: "com.utsstudent.zhaoziying.DayShift",
        category: "SharedStore"
    )

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), planTitle: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task {
            completion(SimpleEntry(date: Date(), planTitle: await firstPlanTitleToday()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entry = SimpleEntry(date: Date(), planTitle: await firstPlanTitleToday())
            // The app reloads the widget after saving, so no scheduled refresh is needed.
            completion(Timeline(entries: [entry], policy: .never))
        }
    }

    /// Falls back to the empty state if the shared store can't be opened or read.
    private func firstPlanTitleToday() async -> String? {
        do {
            let repository = CoreDataActivityRepository(stack: try CoreDataStack())
            return try await repository.plans(on: Date()).first?.title
        } catch {
            Self.logger.error("Couldn't read today's plans: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let planTitle: String?
}

struct DayShiftWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Text(entry.planTitle ?? "Your day is clear.")
            .font(.headline)
            .multilineTextAlignment(.center)
    }
}

struct DayShiftWidget: Widget {
    let kind: String = "DayShiftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DayShiftWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("DayShift")
        .description("Shows your first plan today.")
    }
}

#Preview(as: .systemSmall) {
    DayShiftWidget()
} timeline: {
    SimpleEntry(date: .now, planTitle: "Client call")
    SimpleEntry(date: .now, planTitle: nil)
}
