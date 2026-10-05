import SwiftUI

/// Up to three options for a plan, or why there are none (prototype
/// OptionsRun, OptionsFocus, OptionsGrocery, OptionsNone).
struct OptionsView: View {
    @State private var viewModel: OptionsViewModel
    @Environment(\.dismiss) private var dismiss
    /// Called with the toast after an option is used, so Today can show it.
    private let onAccepted: (String) -> Void

    init(viewModel: OptionsViewModel, onAccepted: @escaping (String) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAccepted = onAccepted
    }

    var body: some View {
        List {
            Section("Current plan") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.currentSummary)
                        .font(.headline)
                    StatusLabel(status: viewModel.status)
                    if let note = viewModel.currentNote {
                        Text(note).font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }

            if let error = viewModel.acceptError {
                Section {
                    BannerView(systemImage: "exclamationmark.circle", title: error.title, detail: error.detail)
                }
            }

            if viewModel.isLoading && viewModel.options.isEmpty && viewModel.noResult == nil {
                Section {
                    ProgressView("Looking for other times and places…")
                }
            }

            if let noResult = viewModel.noResult {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(noResult.title).font(.headline)
                        Text(noResult.detail).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let heading = viewModel.optionsHeading {
                Section(heading) {
                    ForEach(viewModel.options) { card in
                        OptionCardView(card: card, isAccepting: viewModel.isAccepting) {
                            Task {
                                if let toast = await viewModel.use(card) {
                                    onAccepted(toast)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button("Keep my plan") { dismiss() }
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.teal)
        .task { await viewModel.load() }
    }
}

private struct OptionCardView: View {
    let card: OptionsViewModel.OptionCard
    let isAccepting: Bool
    let onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if card.isRecommended {
                Text("Recommended")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.teal.opacity(0.15), in: Capsule())
                    .foregroundStyle(.teal)
            }
            Text(card.title).font(.headline)
            Text(card.explanation).font(.subheadline)
            Text(card.scheduleNote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Use this plan", action: onUse)
                .buttonStyle(.borderedProminent)
                .disabled(isAccepting)
        }
        .padding(.vertical, 6)
    }
}
