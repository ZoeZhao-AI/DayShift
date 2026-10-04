//
//  DayShiftApp.swift
//  DayShift
//
//  Created by Alex W on 3/10/2026.
//

import SwiftUI

@main
struct DayShiftApp: App {
    /// Built once at launch. If the shared store can't be opened, the app shows
    /// what went wrong instead of crashing (Section 4.4).
    @State private var dependencies = Result { try AppDependencies() }

    var body: some Scene {
        WindowGroup {
            switch dependencies {
            case .success(let dependencies):
                TodayView(
                    viewModel: dependencies.today,
                    makePlanEditor: { dependencies.makePlanEditor(editing: $0) },
                    makePlanDetail: { dependencies.makePlanDetail(for: $0) }
                )
            case .failure(let error):
                ErrorScreen(error: error)
            }
        }
    }
}
