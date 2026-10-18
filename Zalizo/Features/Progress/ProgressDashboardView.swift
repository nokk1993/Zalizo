import SwiftUI

struct ProgressDashboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Прогрес", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Тут будуть графіки, рекорди, вага і заміри.")
            }
            .navigationTitle("Прогрес")
        }
    }
}

#Preview {
    ProgressDashboardView()
        .previewData()
}
