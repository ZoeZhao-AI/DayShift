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
    let today: TodayViewModel
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
        let notifications = PlaceholderNotificationScheduler()

        let checkUpcomingPlans = CheckUpcomingPlansUseCase(
            activities: activities,
            places: places,
            preferences: preferences,
            conditions: OpenMeteoConditionsService(),
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

        self.activities = activities
        self.places = places
        self.preferences = preferences
        self.checkUpcomingPlans = checkUpcomingPlans
        self.planActivity = planActivity
        self.calendar = calendar
        today = TodayViewModel(
            checkUpcomingPlans: checkUpcomingPlans,
            activities: activities,
            places: places,
            alertsStatus: NotificationSettingsAlertsStatus(),
            calendar: calendar
        )
    }

    /// A Plan Editor for a new plan, or for `plan` when editing.
    func makePlanEditor(editing plan: PlannedActivity? = nil) -> PlanEditorViewModel {
        PlanEditorViewModel(editing: plan, planActivity: planActivity, places: places, calendar: calendar)
    }
}
