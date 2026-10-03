//
//  ContentView.swift
//  DayShift
//
//  Created by Alex W on 3/10/2026.
//

import DayShiftKit
import SwiftUI
import WidgetKit

/// Temporary screen for the shared-store spike (Section 9, Step 2).
struct ContentView: View {
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Button("Save test plan", action: saveTestPlan)
                .buttonStyle(.borderedProminent)

            if let resultMessage {
                Text(resultMessage)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func saveTestPlan() {
        do {
            let store = try SpikePlanStore()
            try store.saveSamplePlan(title: "Run · Enmore Park")
            WidgetCenter.shared.reloadAllTimelines()
            resultMessage = "Saved \"Run · Enmore Park\". Check the widget."
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
