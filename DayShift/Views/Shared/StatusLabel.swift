import SwiftUI

/// Status is always icon + words; amber only for "Needs attention" (7.4).
struct StatusLabel: View {
    let status: PlanDisplayStatus

    var body: some View {
        switch status {
        case .needsAttention:
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline.weight(.semibold))
        case .looksGood:
            Label("Looks good", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .notCheckedYet:
            Label("Not checked yet", systemImage: "clock")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .inProgress:
            Label("In progress", systemImage: "play.circle")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .done:
            Label("Done", systemImage: "checkmark")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        case .checkedOnTheDay:
            Label("Checked on the day", systemImage: "calendar")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}
