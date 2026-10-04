import SwiftUI
import UIKit

/// Today: Lin's plans with their status, the empty state, and the
/// alerts-off and conditions-unavailable banners (prototype Today,
/// TodayEmpty, TodayBanners).
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    init(viewModel: TodayViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
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
                    }
                } else if !viewModel.rows.isEmpty {
                    Section("Your plans") {
                        ForEach(viewModel.rows) { row in
                            PlanRowView(row: row)
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
            .refreshable { await viewModel.refresh() }
        }
        .tint(.teal)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await viewModel.refresh() }
            }
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

/// Status is always icon + words; amber only for "Needs attention" (7.4).
struct StatusLabel: View {
    let status: TodayViewModel.Status

    var body: some View {
        switch status {
        case .needsAttention:
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline.weight(.semibold))
        case .looksGood:
            Label("Looks good", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .notCheckedYet:
            Label("Not checked yet", systemImage: "clock")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .inProgress:
            Label("In progress", systemImage: "play.circle")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .done:
            Label("Done", systemImage: "checkmark")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}

#Preview {
    if let dependencies = try? AppDependencies() {
        TodayView(viewModel: dependencies.today)
    }
}
