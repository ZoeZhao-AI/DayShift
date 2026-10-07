import DayShiftKit
import Foundation

/// Builds the app's repositories, services and use cases once, around the
/// shared Core Data store.
@MainActor
final class AppDependencies {
    let activities: ActivityRepository
    let places: PlaceRepository
    let preferences: PreferencesRepository
    let checkUpcomingPlans: CheckUpcomingPlansUseCase
    let planActivity: PlanActivityUseCase
    let suggestAlternatives: SuggestAlternativesUseCase
    let savePlace: SavePlaceUseCase
    let updatePreferences: UpdateComfortPreferencesUseCase
    let acceptAlternative: AcceptAlternativeUseCase
    let today: TodayViewModel
    /// Kept here because the notification centre holds its delegate weakly.
    let notificationRouter = NotificationRouter()
    private let conditions: ConditionsService
    private let widget: WidgetRefreshing
    private let notifications: NotificationScheduling
    private let calendar: Calendar

    /// - Throws: `CoreDataStackError` if the shared store can't be opened.
    init() throws {
        let stack = try CoreDataStack()
        let calendar = Calendar.current
        let activities = CoreDataActivityRepository(stack: stack, calendar: calendar)
        let places = CoreDataPlaceRepository(stack: stack)
        let preferences = CoreDataPreferencesRepository(stack: stack)
        let travelTimes = StraightLineTravelTimeService()
        let widget = WidgetCenterRefresher()
        let conditions = OpenMeteoConditionsService()
        let suggestAlternatives = SuggestAlternativesUseCase(
            activities: activities,
            places: places,
            preferences: preferences,
            conditions: conditions,
            travelTimes: travelTimes,
            calendar: calendar
        )
        LocalNotificationScheduler.registerCategory()
        notificationRouter.becomeDelegate()
        let notifications = LocalNotificationScheduler(
            activities: activities,
            preferences: preferences,
            conditions: conditions,
            suggestAlternatives: suggestAlternatives,
            calendar: calendar
        )

        let checkUpcomingPlans = CheckUpcomingPlansUseCase(
            activities: activities,
            places: places,
            preferences: preferences,
            conditions: conditions,
            travelTimes: travelTimes,
            widget: widget,
            notifications: notifications,
            calendar: calendar
        )
        let planActivity = PlanActivityUseCase(
            activities: activities,
            places: places,
            preferences: preferences,
            travelTimes: travelTimes,
            planChecker: checkUpcomingPlans,
            widget: widget,
            notifications: notifications,
            calendar: calendar
        )

        let acceptAlternative = AcceptAlternativeUseCase(
            activities: activities,
            places: places,
            preferences: preferences,
            conditions: conditions,
            travelTimes: travelTimes,
            planChecker: checkUpcomingPlans,
            widget: widget,
            notifications: notifications,
            calendar: calendar
        )

        self.savePlace = SavePlaceUseCase(places: places, geocoder: CLGeocoderPlaceGeocoder())
        self.updatePreferences = UpdateComfortPreferencesUseCase(preferences: preferences, widget: widget)
        self.activities = activities
        self.suggestAlternatives = suggestAlternatives
        self.acceptAlternative = acceptAlternative
        self.places = places
        self.preferences = preferences
        self.checkUpcomingPlans = checkUpcomingPlans
        self.planActivity = planActivity
        self.conditions = conditions
        self.widget = widget
        self.notifications = notifications
        self.calendar = calendar
        today = TodayViewModel(
            checkUpcomingPlans: checkUpcomingPlans,
            activities: activities,
            alertsStatus: NotificationSettingsAlertsStatus(),
            calendar: calendar
        )
    }

    /// A Plan Editor for a new plan, or for `plan` when editing.
    func makePlanEditor(editing plan: PlannedActivity? = nil) -> PlanEditorViewModel {
        PlanEditorViewModel(editing: plan, planActivity: planActivity, places: places, calendar: calendar)
    }

    func makeSettings() -> SettingsViewModel {
        SettingsViewModel(
            preferences: preferences,
            updatePreferences: updatePreferences,
            checkUpcomingPlans: checkUpcomingPlans,
            alertsStatus: NotificationSettingsAlertsStatus(),
            calendar: calendar
        )
    }

    func makeMyPlaces() -> MyPlacesViewModel {
        MyPlacesViewModel(places: places, checkUpcomingPlans: checkUpcomingPlans)
    }

    /// A Place Editor for a new place, or for a saved place when editing.
    func makePlaceEditor(editing place: Place? = nil) -> PlaceEditorViewModel {
        PlaceEditorViewModel(editing: place, savePlace: savePlace, calendar: calendar)
    }

    func makeOptions(for plan: PlannedActivity) -> OptionsViewModel {
        OptionsViewModel(
            plan: plan,
            suggestAlternatives: suggestAlternatives,
            acceptAlternative: acceptAlternative,
            activities: activities,
            calendar: calendar
        )
    }

    func makePlanDetail(for plan: PlannedActivity) -> PlanDetailViewModel {
        PlanDetailViewModel(
            plan: plan,
            activities: activities,
            preferences: preferences,
            conditions: conditions,
            widget: widget,
            notifications: notifications,
            calendar: calendar
        )
    }
}
