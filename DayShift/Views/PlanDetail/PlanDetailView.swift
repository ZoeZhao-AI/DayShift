import Charts
import DayShiftKit
import SwiftUI

/// One plan in detail: status, the four check rows with a chart for the
/// problem condition, and Edit / Delete (prototype PlanDetailRun/Focus/Grocery/Call).
struct PlanDetailView: View {
    @State private var viewModel: PlanDetailViewModel
    @State private var planEditor: PlanEditorViewModel?
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss
    private let makePlanEditor: (PlannedActivity?) -> PlanEditorViewModel
    /// Called after the plan is edited or deleted, so Today can refresh.
    private let onChanged: () -> Void

    init(
        viewModel: PlanDetailViewModel,
        makePlanEditor: @escaping (PlannedActivity?) -> PlanEditorViewModel,
        onChanged: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makePlanEditor = makePlanEditor
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.plan.title)
                        .font(.title.bold())
                    Text("\(viewModel.timeText) · \(viewModel.placeText)")
                        .foregroundStyle(.secondary)
                    StatusLabel(status: viewModel.status)
                }
                .padding(.vertical, 4)
            }

            if let error = viewModel.error {
                Section {
                    BannerView(systemImage: "exclamationmark.circle", title: error.title, detail: error.detail)
                }
            }

            if let note = viewModel.note {
                Section {
                    Text(note).foregroundStyle(.secondary)
                }
            }

            ForEach(viewModel.rows) { row in
                Section {
                    CheckRowView(row: row)
                    if row.id == .conditions, let chart = viewModel.chart {
                        ConditionChartView(chart: chart)
                    }
                }
            }

            if let checkedText = viewModel.checkedText {
                Section {
                } footer: {
                    Text(checkedText).frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section {
                if viewModel.canEdit {
                    Button("Edit plan") {
                        planEditor = makePlanEditor(viewModel.plan)
                    }
                }
                Button("Delete plan", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .navigationTitle(viewModel.plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.teal)
        .task { await viewModel.load() }
        .confirmationDialog("Delete this plan?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete plan", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        onChanged()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("DayShift stops checking it and removes its reminders.")
        }
        .sheet(item: $planEditor) { editor in
            PlanEditorView(viewModel: editor) {
                if let savedPlan = editor.savedPlan {
                    viewModel.replace(with: savedPlan)
                }
                Task { await viewModel.load() }
                onChanged()
            }
        }
    }
}

/// "Conditions", "Travel", "Opening hours" or "Crowds", with its findings.
private struct CheckRowView: View {
    let row: PlanDetailViewModel.CheckRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(row.title, systemImage: row.symbolName)
                    .font(.headline)
                Spacer()
                severityIcon
            }
            ForEach(row.lines, id: \.self) { line in
                if line.isTip {
                    (Text("Tip · ").bold() + Text(line.text))
                        .font(.subheadline)
                } else {
                    Text(line.text)
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var severityIcon: some View {
        switch row.severity {
        case .problem:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Needs attention")
        case .tip:
            Image(systemName: "lightbulb")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Tip")
        case .fine:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Looks good")
        }
    }
}

/// The problem condition by the hour, a dashed line at Lin's limit, and the
/// hours worse than the limit shaded (prototype PlanDetailRun, PlanDetailFocus).
private struct ConditionChartView: View {
    let chart: PlanDetailViewModel.ConditionChart

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(chart.points) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        yStart: .value("Limit", chart.limit),
                        yEnd: .value(chart.valueName, max(point.value, chart.limit))
                    )
                    .foregroundStyle(Color.orange.opacity(0.25))

                    LineMark(
                        x: .value("Time", point.time),
                        y: .value(chart.valueName, point.value)
                    )
                    .foregroundStyle(Color.primary)
                }

                RuleMark(y: .value("Limit", chart.limit))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text(chart.limitLabel).font(.caption).foregroundStyle(.secondary)
                    }

                if let now = chart.now {
                    RuleMark(x: .value("Now", now))
                        .foregroundStyle(.teal)
                        .annotation(position: .top) {
                            Text("Now").font(.caption.bold()).foregroundStyle(.teal)
                        }
                }
            }
            .chartYAxisLabel(chart.valueName)
            .frame(height: 180)
            .accessibilityLabel(chart.caption)

            Text(chart.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
