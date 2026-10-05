import DayShiftKit
import SwiftUI
import UIKit

/// Today: Lin's plans with their status, the empty state, and the
/// alerts-off and conditions-unavailable banners (prototype Today,
/// TodayEmpty, TodayBanners).
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var planEditor: PlanEditorViewModel?
    @State private var path = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    private let makePlanEditor: (PlannedActivity?) -> PlanEditorViewModel
    private let makePlanDetail: (PlannedActivity) -> PlanDetailViewModel
    private let makeOptions: (PlannedActivity) -> OptionsViewModel

    init(
        viewModel: TodayViewModel,
        makePlanEditor: @escaping (PlannedActivity?) -> PlanEditorViewModel,
        makePlanDetail: @escaping (PlannedActivity) -> PlanDetailViewModel,
        makeOptions: @escaping (PlannedActivity) -> OptionsViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makePlanEditor = makePlanEditor
        self.makePlanDetail = makePlanDetail
        self.makeOptions = makeOptions
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Text(viewModel.weekday)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                if viewModel.alertsAreOff {
                    Section {
                        BannerView(
                            systemImage: "bell.slash",
                            title: "Alerts are off.",
                            detail: "Turn them on in Settings to get leave reminders."
                        )
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }

                if let banner = viewModel.problemBanner {
                    Section {
                        BannerView(systemImage: "cloud.slash", title: banner.title, detail: banner.detail)
                    }
                }

                if viewModel.hasLoaded && viewModel.rows.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your day is clear.")
                                .font(.title2.bold())
                            Text("Plan something and DayShift will keep an eye on it.")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        Button("Plan an activity") { planEditor = makePlanEditor(nil) }
                    }
                } else if !viewModel.rows.isEmpty {
                    Section("Your plans") {
                        ForEach(viewModel.rows) { row in
                            planButton(for: row)
                        }
                    }
                }

                ForEach(Array(viewModel.comingUp.enumerated()), id: \.element.id) { index, day in
                    Section {
                        ForEach(day.rows) { row in
                            planButton(for: row)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            if index == 0 {
                                Text("Coming up")
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                    .textCase(nil)
                            }
                            Text(day.title)
                        }
                    }
                }

                if viewModel.showsAddSamplePlaces {
                    Section {
                        Button("Add sample places") {
                            Task { await viewModel.addSamplePlaces() }
                        }
                    } footer: {
                        Text("Temporary: saves Home, Newtown Library, Enmore Park and Marrickville Metro until My Places is built.")
                    }
                }

                if let footer = viewModel.footer {
                    Section {
                    } footer: {
                        Text(footer)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        planEditor = makePlanEditor(nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Plan an activity")
                }
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: PlanDetailViewModel.self) { detail in
                PlanDetailView(
                    viewModel: detail,
                    makePlanEditor: makePlanEditor,
                    openOptions: { plan in path.append(makeOptions(plan)) },
                    onChanged: { Task { await viewModel.refresh() } }
                )
            }
            .navigationDestination(for: OptionsViewModel.self) { options in
                OptionsView(viewModel: options) { toast in
                    // Back to Today, with the change confirmed (7.4).
                    path = NavigationPath()
                    Task { await viewModel.optionWasUsed(toast: toast) }
                }
            }
            .sheet(item: $planEditor) { editor in
                PlanEditorView(viewModel: editor) {
                    Task { await viewModel.planWasSaved(editor.savedPlan) }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toast {
                    Toast(text: toast)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast) {
                            try? await Task.sleep(for: .seconds(4))
                            withAnimation { viewModel.dismissToast() }
                        }
                }
            }
            .animation(.default, value: viewModel.toast)
        }
        .tint(.teal)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }
}

extension TodayView {
    /// A plan row that opens Plan Detail.
    private func planButton(for row: TodayViewModel.PlanRow) -> some View {
        Button {
            if let plan = viewModel.plan(withID: row.id) {
                path.append(makePlanDetail(plan))
            }
        } label: {
            PlanRowView(row: row)
        }
        .foregroundStyle(Color.primary)
    }
}

/// A short confirmation at the bottom of Today, read out by VoiceOver.
private struct Toast: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .onAppear {
                AccessibilityNotification.Announcement(text).post()
            }
    }
}

/// One plan: time, activity icon, title, place and leave-by, status and reason.
private struct PlanRowView: View {
    let row: TodayViewModel.PlanRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.symbolName)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 28)
                .accessibilityLabel(row.activityName)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.timeText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if row.isMoved {
                        Text("Moved")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.teal.opacity(0.15), in: Capsule())
                            .foregroundStyle(.teal)
                    }
                }
                Text(row.title)
                    .font(.headline)
                Text(row.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                StatusLabel(status: row.status)
                if let reason = row.reason {
                    Text(reason)
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    if let dependencies = try? AppDependencies() {
        TodayView(
            viewModel: dependencies.today,
            makePlanEditor: { dependencies.makePlanEditor(editing: $0) },
            makePlanDetail: { dependencies.makePlanDetail(for: $0) },
            makeOptions: { dependencies.makeOptions(for: $0) }
        )
    }
}
