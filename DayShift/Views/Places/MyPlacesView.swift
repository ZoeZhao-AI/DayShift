import SwiftUI

/// "My Places": where Lin usually goes (prototype MyPlaces).
struct MyPlacesView: View {
    @State private var viewModel: MyPlacesViewModel
    @State private var editor: PlaceEditorViewModel?
    private let makePlaceEditor: (UUID?) -> PlaceEditorViewModel

    init(viewModel: MyPlacesViewModel, makePlaceEditor: @escaping (UUID?) -> PlaceEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.makePlaceEditor = makePlaceEditor
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.rows) { row in
                        Button {
                            editor = makePlaceEditor(row.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: row.symbolName)
                                    .font(.title3)
                                    .foregroundStyle(.teal)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name).font(.headline)
                                    Text(row.detail).font(.subheadline).foregroundStyle(.secondary)
                                    Text(row.comfort).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .foregroundStyle(Color.primary)
                    }
                    if viewModel.hasLoaded && viewModel.rows.isEmpty {
                        Text("No places yet. Add Home first, so DayShift can work out travel times.")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Where you usually go. DayShift uses these details to check your plans.")
                }

                if let error = viewModel.error {
                    Section {
                        BannerView(systemImage: "exclamationmark.circle", title: error.title, detail: error.detail)
                    }
                }

                Section {
                    Button {
                        editor = makePlaceEditor(nil)
                    } label: {
                        Label("Add a place", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("My Places")
            .task { await viewModel.load() }
            .sheet(item: $editor) { editor in
                PlaceEditorView(viewModel: editor) {
                    Task { await viewModel.placeWasSaved() }
                }
            }
        }
        .tint(.teal)
    }
}
