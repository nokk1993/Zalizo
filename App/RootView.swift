import ShahCore
import SwiftUI

/// Onboarding on first launch, then the three tabs.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.settings.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: model.settings.hasCompletedOnboarding)
        .onSystemClockChange { model.handleClockChange() }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сьогодні", systemImage: "figure.walk") }
            HistoryView()
                .tabItem { Label("Історія", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Налаштування", systemImage: "gearshape") }
        }
    }
}

#Preview {
    PreviewHost { RootView() }
}
