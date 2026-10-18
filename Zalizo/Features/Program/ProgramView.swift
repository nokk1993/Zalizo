import SwiftUI

struct ProgramView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Програма", systemImage: "list.bullet.clipboard")
            } description: {
                Text("Тут буде твоя тренувальна програма і бібліотека вправ.")
            }
            .navigationTitle("Програма")
        }
    }
}

#Preview {
    ProgramView()
        .previewData()
}
