import SwiftUI

struct NutritionView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Харчування", systemImage: "fork.knife")
            } description: {
                Text("Тут будуть норми калорій, меню і трекер води.")
            }
            .navigationTitle("Харчування")
        }
    }
}

#Preview {
    NutritionView()
        .previewData()
}
