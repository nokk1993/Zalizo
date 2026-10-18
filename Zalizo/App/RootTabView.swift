import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab("Сьогодні", systemImage: "flame", value: AppTab.today) {
                TodayView()
            }
            Tab("Програма", systemImage: "list.bullet.clipboard", value: AppTab.program) {
                ProgramView()
            }
            Tab("Прогрес", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressDashboardView()
            }
            Tab("Харчування", systemImage: "fork.knife", value: AppTab.nutrition) {
                NutritionView()
            }
            Tab("Профіль", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootTabView()
        .environment(AppState())
        .previewData()
}
