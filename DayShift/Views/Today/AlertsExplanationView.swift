import SwiftUI

/// Shown once, the first time a plan is saved, before iOS asks for
/// permission (6.3; replaces the prototype's AlertsPermission screen).
struct AlertsExplanationView: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.largeTitle)
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            Text("Stay a step ahead")
                .font(.title2.bold())
            Text("Allow alerts so DayShift can remind you when to leave and tell you when a plan is affected.")
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    VStack(alignment: .leading) {
                        Text("Leave reminders").font(.headline)
                        Text("Before you need to go, with conditions on the way.").foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "figure.walk").foregroundStyle(.teal)
                }
                Label {
                    VStack(alignment: .leading) {
                        Text("When a plan is affected").font(.headline)
                        Text("Smoke, heat, UV, wind or rain, with a better option ready.").foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.teal)
                }
            }
            Spacer(minLength: 0)
            Button(action: onAllow) {
                Text("Allow alerts").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button(action: onNotNow) {
                Text("Not now").frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .tint(.teal)
        .presentationDetents([.medium, .large])
    }
}
