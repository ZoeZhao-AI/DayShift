import DayShiftKit
import SwiftUI

/// Status is always icon + words; amber only for "Needs attention" (7.4).
/// The words and icons come from `PlanDisplayStatus`, shared with the widget.
struct StatusLabel: View {
    let status: PlanDisplayStatus

    var body: some View {
        Label(status.text, systemImage: status.symbolName)
            .foregroundStyle(status == .needsAttention ? Color.orange : Color.secondary)
            .font(status == .needsAttention ? .subheadline.weight(.semibold) : .subheadline)
    }
}
