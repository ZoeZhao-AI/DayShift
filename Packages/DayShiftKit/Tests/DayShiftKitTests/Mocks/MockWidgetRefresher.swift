import Foundation
@testable import DayShiftKit

/// Counts widget reloads. `reload()` doesn't throw, so this mock can't be set to throw.
final class MockWidgetRefresher: WidgetRefreshing {
    private(set) var reloadCount = 0

    func reload() {
        reloadCount += 1
    }
}
