import DayShiftKit
import SwiftUI

/// "Plan an activity" sheet (prototype PlanEditor, PlanEditorError).
struct PlanEditorView: View {
    @State private var viewModel: PlanEditorViewModel
    @Environment(\.dismiss) private var dismiss
    /// Called after the plan is saved, so Today can refresh.
    let onSaved: () -> Void

    init(viewModel: PlanEditorViewModel, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                activitySection
                placeSection
                whenSection
                if let error = viewModel.inlineError {
                    Section {
                        BannerView(systemImage: "exclamationmark.circle", title: error.title, detail: error.detail)
                    }
                }
                flexibilitySection
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save plan") {
                        Task {
                            if await viewModel.save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task { await viewModel.load() }
        }
        .tint(.teal)
    }

    private var activitySection: some View {
        Section("Activity") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.activityTypes) { type in
                        ActivityChip(type: type, isSelected: type.id == viewModel.selectedTypeID) {
                            viewModel.selectedTypeID = type.id
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var placeSection: some View {
        Section {
            ForEach(viewModel.suitablePlaces) { place in
                SelectableRow(
                    title: place.name,
                    subtitle: place.suburb,
                    isSelected: !viewModel.isOnline && viewModel.selectedPlaceID == place.id
                ) {
                    viewModel.isOnline = false
                    viewModel.selectedPlaceID = place.id
                }
            }
            if viewModel.canBeOnline {
                SelectableRow(title: "Online", subtitle: nil, isSelected: viewModel.isOnline) {
                    viewModel.isOnline = true
                    viewModel.selectedPlaceID = nil
                }
            }
        } header: {
            Text("Place")
        } footer: {
            Text(viewModel.placeNote)
        }
    }

    private var whenSection: some View {
        Section("When") {
            DatePicker("Date", selection: $viewModel.start, displayedComponents: .date)
            DatePicker("Start time", selection: $viewModel.start, displayedComponents: .hourAndMinute)
            Stepper(value: $viewModel.durationMinutes, in: 15...720, step: 15) {
                LabeledContent("Duration", value: PlanEditorViewModel.durationText(viewModel.durationMinutes))
            }
        }
    }

    private var flexibilitySection: some View {
        Section {
            Toggle("Can move", isOn: $viewModel.canMove)
            if viewModel.canMove {
                DatePicker("Between", selection: $viewModel.windowStart, displayedComponents: .hourAndMinute)
                DatePicker("And", selection: $viewModel.windowEnd, displayedComponents: .hourAndMinute)
            }
            if !viewModel.isOnline {
                Toggle("Can change place", isOn: $viewModel.canChangePlace)
            }
        } header: {
            Text("Flexibility")
        } footer: {
            Text("DayShift only suggests changes you allow here.")
        }
    }
}

private struct ActivityChip: View {
    let type: ActivityType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(type.name, systemImage: type.symbolName)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.teal : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectableRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).foregroundStyle(Color.primary)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.teal)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
