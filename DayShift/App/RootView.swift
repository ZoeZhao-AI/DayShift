import DayShiftKit
import SwiftUI

/// The tab bar (Section 7.2): Today | My Places | Settings. Links from the
/// widget and notifications always open on Today.
struct RootView: View {
    enum Tab: Hashable {
        case today
        case myPlaces
        case settings
    }

    private let dependencies: AppDependencies
    @State private var selection: Tab = .today
    /// A link waiting for Today to open it.
    @State private var incomingLink: DeepLink?
    @State private var myPlaces: MyPlacesViewModel
    @State private var settings: SettingsViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _myPlaces = State(initialValue: dependencies.makeMyPlaces())
        _settings = State(initialValue: dependencies.makeSettings())
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayView(
                viewModel: dependencies.today,
                incomingLink: $incomingLink,
                makePlanEditor: { dependencies.makePlanEditor(editing: $0) },
                makePlanDetail: { dependencies.makePlanDetail(for: $0) },
                makeOptions: { dependencies.makeOptions(for: $0) }
            )
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            MyPlacesView(viewModel: myPlaces) { id in
                dependencies.makePlaceEditor(editing: id.flatMap { myPlaces.place(withID: $0) })
            }
            .tabItem { Label("My Places", systemImage: "mappin.and.ellipse") }
            .tag(Tab.myPlaces)

            SettingsView(viewModel: settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(.teal)
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else { return }
            open(link)
        }
        .onChange(of: dependencies.notificationRouter.pendingLink, initial: true) { _, link in
            guard let link else { return }
            dependencies.notificationRouter.linkOpened()
            open(link)
        }
    }

    private func open(_ link: DeepLink) {
        selection = .today
        incomingLink = link
    }
}
