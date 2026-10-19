import Combine
import ShahCore
import SwiftUI
import UIKit

/// Phase 2 skeleton: proves the Health → repository → UI pipeline.
/// Onboarding, tabs and the designed screens arrive in phase 3.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TodayView()
            .task {
                if !model.settings.hasCompletedOnboarding {
                    await model.requestAuthorization()
                    model.updateSettings { $0.hasCompletedOnboarding = true }
                }
            }
            // Midnight, manual clock changes and time-zone changes.
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                model.handleClockChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                model.handleClockChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: RunLoop.main)) { _ in
                model.handleClockChange()
            }
    }
}
