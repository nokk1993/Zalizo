import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab("Сьогодні", systemImage: "flame", value: AppTab.today) {
                TodayView()
            }
            Tab("Програма", systemImage: "dumbbell", value: AppTab.program) {
                ProgramView()
            }
            Tab("Прогрес", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressDashboardView()
            }
            Tab("Харчування", systemImage: "fork.knife", value: AppTab.nutrition) {
                NutritionView()
            }
            Tab("Профіль", systemImage: "person", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await ReminderService.refresh(in: context) }
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppState())
        .previewData()
}
