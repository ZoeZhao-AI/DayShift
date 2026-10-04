import DayShiftKit
import WidgetKit

/// Reloads every DayShift widget timeline (Section 6.2).
struct WidgetCenterRefresher: WidgetRefreshing {
    func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
