import SwiftUI

/// A problem in Lin's words: what went wrong in bold, what to do next below (7.4).
struct BannerView: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Shown instead of the app when the shared store can't be opened (4.4).
struct ErrorScreen: View {
    let error: Error

    var body: some View {
        let localized = error as? LocalizedError
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(localized?.errorDescription ?? "DayShift couldn't start.")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(localized?.recoverySuggestion ?? "Please reinstall DayShift.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
