import DayShiftKit
import SwiftUI

/// Place Editor for a new or saved place (prototype PlaceEditor, PlaceEditorNew).
struct PlaceEditorView: View {
    @State private var viewModel: PlaceEditorViewModel
    @Environment(\.dismiss) private var dismiss
    /// Called after the place is saved, so My Places can refresh and re-check.
    private let onSaved: () -> Void

    init(viewModel: PlaceEditorViewModel, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.name)
                    Picker("Kind", selection: $viewModel.kind) {
                        ForEach(viewModel.kinds, id: \.self) { kind in
                            Label(kind.name, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    TextField("Address", text: $viewModel.address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                    if let area = viewModel.area {
                        LabeledContent("Area", value: area)
                    }
                } footer: {
                    Text("DayShift looks up the address when you save, to check conditions and travel time there.")
                }

                if let error = viewModel.inlineError {
                    Section {
                        BannerView(systemImage: "exclamationmark.circle", title: error.title, detail: error.detail)
                    }
                }

                Section {
                    Toggle("Indoor", isOn: $viewModel.isIndoor)
                    if viewModel.isIndoor {
                        Toggle("Air-conditioned", isOn: $viewModel.isCooled)
                    }
                    if viewModel.showsHeatLimit {
                        Stepper(value: $viewModel.heatLimitC, in: Place.uncooledHeatLimitRange, step: 1) {
                            Text("It gets too hot here when it's above \(Int(viewModel.heatLimitC))°C outside")
                        }
                    }
                } footer: {
                    if viewModel.isIndoor && viewModel.isCooled {
                        Text("Air-conditioned places stay comfortable, so DayShift won't warn you about heat here.")
                    } else if viewModel.showsHeatLimit {
                        Text("Used to warn you before working here on hot days.")
                    }
                }

                Section {
                    Picker("Opening hours", selection: $viewModel.hoursChoice) {
                        ForEach(PlaceEditorViewModel.HoursChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    if viewModel.hoursChoice == .set {
                        DatePicker("Opens", selection: $viewModel.opensAt, displayedComponents: .hourAndMinute)
                        DatePicker("Closes", selection: $viewModel.closesAt, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Opening hours")
                } footer: {
                    if let typical = viewModel.typicalHoursNote {
                        Text("\(typical)\nCheck and edit if different.")
                    } else if viewModel.hoursChoice == .notSure {
                        Text("Plans here will say \"Opening hours not confirmed.\"")
                    }
                }

                Section("Usual busy times") {
                    Text(viewModel.usualBusyTimes)
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isEditing ? "Done" : "Save place") {
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
        }
        .tint(.teal)
    }
}
