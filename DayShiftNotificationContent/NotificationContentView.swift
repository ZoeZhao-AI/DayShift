import Charts
import DayShiftKit
import SwiftUI

/// LeaveExpanded (A) and AffectedExpanded (B) from the prototype, drawn from
/// the payload. Without a payload, the notification's own text is shown.
struct NotificationContentView: View {
    let title: String
    /// The notification's own text, shown if there is no payload.
    let bodyText: String
    let payload: NotificationPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            switch payload?.situation {
            case .leaveReminder?:
                if let payload { LeaveReminderView(payload: payload) }
            case .planAffected?:
                if let payload { PlanAffectedView(payload: payload) }
            case nil:
                Text(bodyText).font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.teal)
    }
}

// MARK: - A: Leave reminder

private struct LeaveReminderView: View {
    let payload: NotificationPayload

    private var problems: [PlanFinding] { payload.findings.filter { $0.severity == .problem } }
    private var tipsOnTheWay: [PlanFinding] {
        payload.findings.filter { $0.factor == .conditions && $0.severity == .tip }
    }
    /// What Lin will find at the place: its own conditions, opening hours, crowds.
    private var atThePlace: [PlanFinding] {
        payload.findings.filter { finding in
            switch finding.factor {
            case .openingHours, .crowds: return true
            case .conditions: return finding.severity == .fine
            case .travel: return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = tripSummary {
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
            }

            if let onTheWay = payload.onTheWay {
                Section(title: "On the way") {
                    LimitRow(text: "\(Self.whole(onTheWay.feelsLikeC))°C feels like",
                             limit: "your limit \(Self.whole(onTheWay.maxFeelsLikeC))°C",
                             isAbove: onTheWay.feelsLikeC > onTheWay.maxFeelsLikeC)
                    LimitRow(text: "UV \(Self.whole(onTheWay.uvIndex))",
                             limit: "your limit \(Self.whole(onTheWay.maxUVIndex))",
                             isAbove: onTheWay.uvIndex > onTheWay.maxUVIndex)
                    LimitRow(text: "\(onTheWay.rainChance)% chance of rain",
                             limit: "your limit \(onTheWay.maxRainChance)%",
                             isAbove: onTheWay.rainChance > onTheWay.maxRainChance)
                    LimitRow(text: "Air quality \(onTheWay.airQuality.name)",
                             limit: "your limit \(onTheWay.worstAcceptableAirQuality.name)",
                             isAbove: onTheWay.airQuality > onTheWay.worstAcceptableAirQuality)
                    ForEach(tipsOnTheWay, id: \.message) { tip in
                        (Text("Tip  ").bold().foregroundColor(.teal) + Text(tip.message))
                            .font(.subheadline)
                    }
                }
            }

            if !atThePlace.isEmpty {
                Section(title: "At \(payload.placeName ?? "the place")") {
                    ForEach(atThePlace, id: \.message) { finding in
                        Text(finding.message).font(.subheadline)
                    }
                }
            }

            Verdict(problem: problems.first?.message)
        }
    }

    /// "Newtown Library · 12 min by public transport · arrive 12:47 pm".
    private var tripSummary: String? {
        guard let place = payload.placeName else { return nil }
        guard let travel = payload.travel, let leaveBy = payload.leaveBy else { return place }
        let arrival = leaveBy.addingTimeInterval(TimeInterval(travel.minutes * 60))
        return "\(place) · \(travel.text) · arrive \(TimeText.time(arrival))"
    }

    static func whole(_ value: Double) -> String { String(Int(value.rounded())) }
}

private struct LimitRow: View {
    let text: String
    let limit: String
    let isAbove: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.subheadline.weight(isAbove ? .semibold : .regular))
                .foregroundStyle(isAbove ? Color.orange : Color.primary)
            Spacer()
            Text(limit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - B: Plan affected

private struct PlanAffectedView: View {
    let payload: NotificationPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let problem = payload.findings.first(where: { $0.severity == .problem }) {
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if let chart = payload.chart {
                ConditionChartView(chart: chart, place: payload.placeName)
            }

            if let option = payload.topOption {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.teal.opacity(0.15), in: Capsule())
                        .foregroundStyle(.teal)
                    Text(option.title).font(.headline)
                    Text(option.explanation).font(.subheadline)
                    Text(option.scheduleNote).font(.caption).foregroundStyle(.secondary)
                    Text("Tap See options to use it in DayShift.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No better time or place today. Open DayShift for details.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The problem condition by the hour, with a dashed line at Lin's limit and
/// the hours worse than it shaded.
private struct ConditionChartView: View {
    let chart: ConditionChartData
    let place: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(chart.points, id: \.time) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        yStart: .value("Limit", chart.limit),
                        yEnd: .value(chart.valueName, max(point.value, chart.limit))
                    )
                    .foregroundStyle(Color.orange.opacity(0.25))
                    LineMark(x: .value("Time", point.time), y: .value(chart.valueName, point.value))
                        .foregroundStyle(Color.primary)
                }
                RuleMark(y: .value("Limit", chart.limit))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text(chart.limitLabel).font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartYAxisLabel(chart.valueName)
            .frame(height: 140)
            .accessibilityLabel("\(chart.conditionName) by the hour, with your limit")

            Text("\(chart.conditionName)\(place.map { " at \($0)" } ?? "") · shaded where it's worse than your limit")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

/// "✓ Your plan looks good." or the problem, in amber.
private struct Verdict: View {
    let problem: String?

    var body: some View {
        if let problem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        } else {
            Label("Your plan looks good.", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
