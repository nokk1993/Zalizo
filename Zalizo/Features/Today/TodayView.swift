import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Сьогодні", systemImage: "flame")
            } description: {
                Text("Тут з'явиться план на сьогоднішнє тренування.")
            }
            .navigationTitle("Сьогодні")
        }
    }
}

#Preview {
    TodayView()
        .previewData()
}
