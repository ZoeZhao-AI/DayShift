import DayShiftKit
import SwiftUI
import WidgetKit

/// Lin's next plan on the Home Screen (Section 6.2), in small and medium.
struct NextPlanWidget: Widget {
    let kind = "NextPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPlanProvider()) { entry in
            NextPlanWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next plan")
        .description("Your next plan today and whether it still works.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct NextPlanWidgetView: View {
    let entry: NextPlanEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.snapshot.content {
        case let .plans(next, following):
            if family == .systemMedium {
                MediumPlansView(next: next, following: following)
            } else {
                SmallPlanView(line: next)
                    .widgetURL(DeepLink.plan(next.planID).url)
            }
        case let .message(title, detail):
            // Small has one tap target: the coming-up plan if there is one.
            MessageView(title: title, detail: detail, comingUp: entry.snapshot.comingUp, isMedium: family == .systemMedium)
                .widgetURL(family == .systemSmall
                    ? (entry.snapshot.comingUp.map { DeepLink.plan($0.planID).url } ?? DeepLink.today.url)
                    : DeepLink.today.url)
        }
    }
}

/// "Next · 11:00 am", title, place, status, and the reason or "Leave by …".
private struct SmallPlanView: View {
    let line: WidgetSnapshot.PlanLine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next · \(line.timeText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(line.title)
                .font(.headline)
                .lineLimit(2)
            Text(line.placeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            WidgetStatusLabel(status: line.status)
            if let detail = line.reason ?? line.leaveByText {
                Text(detail)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The next plan in detail, then the following two plans in one line each.
/// Each row opens its own plan.
private struct MediumPlansView: View {
    let next: WidgetSnapshot.PlanLine
    let following: [WidgetSnapshot.PlanLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Link(destination: DeepLink.plan(next.planID).url) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next · \(next.timeText) · \(next.placeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(next.title)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        WidgetStatusLabel(status: next.status)
                        if let leaveBy = next.leaveByText, next.reason == nil {
                            Text(leaveBy).font(.caption)
                        }
                    }
                    if let reason = next.reason {
                        Text(reason)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !following.isEmpty {
                Divider()
                ForEach(following, id: \.planID) { line in
                    Link(destination: DeepLink.plan(line.planID).url) {
                        HStack(spacing: 6) {
                            Text(line.timeText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(line.title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: line.status.symbolName)
                                .font(.caption)
                                .foregroundStyle(line.status == .needsAttention ? Color.orange : Color.secondary)
                                .accessibilityLabel(line.status.text)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// "Your day is clear." / "That's everything for today.", and below it the
/// next plan coming up, without a status (6.2).
private struct MessageView: View {
    let title: String
    let detail: String?
    let comingUp: WidgetSnapshot.ComingUpLine?
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let comingUp {
                Spacer(minLength: 4)
                if isMedium {
                    Link(destination: DeepLink.plan(comingUp.planID).url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coming up · \(comingUp.dayText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(comingUp.timeText) \(comingUp.title) · \(comingUp.placeText)")
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("\(comingUp.dayText) \(comingUp.timeText) · \(comingUp.title)")
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Icon + words; amber only for "Needs attention" (7.4).
private struct WidgetStatusLabel: View {
    let status: PlanDisplayStatus

    var body: some View {
        Label(status.text, systemImage: status.symbolName)
            .font(.caption.weight(status == .needsAttention ? .semibold : .regular))
            .foregroundStyle(status == .needsAttention ? Color.orange : Color.secondary)
            .lineLimit(1)
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    NextPlanWidget()
} timeline: {
    NextPlanEntry.placeholder
    NextPlanEntry(date: .now, snapshot: WidgetSnapshot(content: .message(title: "Your day is clear.", detail: "Plan an activity in DayShift.")))
}

#Preview(as: .systemMedium) {
    NextPlanWidget()
} timeline: {
    NextPlanEntry.placeholder
    NextPlanEntry(date: .now, snapshot: WidgetSnapshot(
        content: .message(title: "That's everything for today.", detail: nil),
        comingUp: WidgetSnapshot.ComingUpLine(
            planID: UUID(), title: "Run", dayText: "Tomorrow", timeText: "7:00 am", placeText: "Enmore Park"
        )
    ))
}
