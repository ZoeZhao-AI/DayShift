import Foundation

/// Asks the widget to read the shared store again (Section 6.2).
public protocol WidgetRefreshing {
    func reload()
}
