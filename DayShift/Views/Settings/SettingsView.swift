import DayShiftKit
import SwiftUI
import UIKit

/// Settings: Your limits, Your day and Alerts (prototype Settings), with
/// the ranges from 2.7.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.saveError {
                    Section {
                        BannerView(systemImage: "exclamationmark.circle", title: error.title, detail: error.detail)
                    }
                }

                Section {
                    Stepper(value: $viewModel.draft.maxApparentTemperatureC,
                            in: ComfortPreferences.maxApparentTemperatureRange, step: 1) {
                        LabeledContent("Max feels-like", value: "\(Int(viewModel.draft.maxApparentTemperatureC))°C")
                    }
                    Picker("Worst air quality", selection: $viewModel.draft.worstAcceptableAirQuality) {
                        ForEach(AirQualityCategory.allCases.filter { ComfortPreferences.worstAcceptableAirQualityRange.contains($0) }, id: \.self) {
                            Text($0.name).tag($0)
                        }
                    }
                    Stepper(value: $viewModel.draft.maxUVIndex, in: ComfortPreferences.maxUVIndexRange, step: 1) {
                        LabeledContent("Max UV", value: "\(Int(viewModel.draft.maxUVIndex))")
                    }
                    Stepper(value: $viewModel.draft.maxWindGustsKmh, in: ComfortPreferences.maxWindGustsRange, step: 5) {
                        LabeledContent("Max wind gusts", value: "\(Int(viewModel.draft.maxWindGustsKmh)) km/h")
                    }
                    Stepper(value: $viewModel.draft.maxRainProbability, in: ComfortPreferences.maxRainProbabilityRange, step: 5) {
                        LabeledContent("Max chance of rain", value: "\(viewModel.draft.maxRainProbability)%")
                    }
                } header: {
                    Text("Your limits")
                } footer: {
                    Text("DayShift flags a plan when the forecast goes past any of these.")
                }

                Section("Your day") {
                    DatePicker("Plan from", selection: $viewModel.earliestTime, displayedComponents: .hourAndMinute)
                    DatePicker("Plan until", selection: $viewModel.latestTime, displayedComponents: .hourAndMinute)
                    Stepper(value: $viewModel.draft.minimumBufferMinutes, in: ComfortPreferences.minimumBufferRange, step: 5) {
                        LabeledContent("Time between plans", value: "\(viewModel.draft.minimumBufferMinutes) min")
                    }
                    Picker("Travel", selection: $viewModel.draft.travelMode) {
                        ForEach(TravelMode.allCases, id: \.self) {
                            Text(SettingsViewModel.name(of: $0)).tag($0)
                        }
                    }
                    Stepper(value: $viewModel.draft.leaveReminderMinutes, in: ComfortPreferences.leaveReminderRange, step: 5) {
                        LabeledContent("Leave reminder", value: "\(viewModel.draft.leaveReminderMinutes) min before")
                    }
                }

                Section {
                    switch viewModel.alerts {
                    case .allowed:
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    case .off:
                        Label("Off", systemImage: "bell.slash")
                            .foregroundStyle(.secondary)
                    case .notAskedYet:
                        Button("Allow alerts") {
                            Task { await viewModel.allowAlerts() }
                        }
                    }
                    if viewModel.alerts != .notAskedYet {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    switch viewModel.alerts {
                    case .allowed: Text("Leave reminders and plan alerts are on.")
                    case .off: Text("Turn them on in iOS Settings to get leave reminders.")
                    case .notAskedYet: Text("DayShift reminds you when to leave and tells you when a plan is affected.")
                    }
                }

                if let message = viewModel.savedMessage {
                    Section {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if viewModel.hasChanges {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Discard changes") { viewModel.discardChanges() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save changes") {
                            Task { await viewModel.save() }
                        }
                        .disabled(viewModel.saveError != nil)
                    }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: scenePhase) { _, phase in
                // Alerts may have been changed in iOS Settings.
                if phase == .active {
                    Task { await viewModel.loadAlerts() }
                }
            }
        }
        .tint(.teal)
    }
}
