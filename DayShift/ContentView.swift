//
//  ContentView.swift
//  DayShift
//
//  Created by Alex W on 3/10/2026.
//

import DayShiftKit
import SwiftUI
import WidgetKit

/// Temporary screen for the shared-store spike (Section 9, Step 2),
/// now saving through ActivityRepository. Replaced by Today in Step 3.
struct ContentView: View {
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Button("Save test plan") {
                Task { await saveTestPlan() }
            }
            .buttonStyle(.borderedProminent)

            if let resultMessage {
                Text(resultMessage)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    /// Saves a 30-minute online Client call starting now, then reloads the widget.
    @MainActor
    private func saveTestPlan() async {
        do {
            let repository = CoreDataActivityRepository(stack: try CoreDataStack())
            let clientCall = try PlannedActivity(
                typeID: ActivityCatalogue.clientMeeting.id,
                title: "Client call",
                start: Date(),
                durationMinutes: 30,
                place: nil,
                mode: .online,
                flexibility: .fixed
            )
            try await repository.save(clientCall)
            WidgetCenter.shared.reloadAllTimelines()
            resultMessage = "Saved \"Client call\". Check the widget."
        } catch {
            let localized = error as? LocalizedError
            resultMessage = [
                localized?.errorDescription ?? "Your test plan couldn't be saved.",
                localized?.recoverySuggestion ?? "Please try again."
            ].joined(separator: "\n")
        }
    }
}

#Preview {
    ContentView()
}
