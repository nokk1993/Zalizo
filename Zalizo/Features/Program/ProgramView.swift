import SwiftUI

struct ProgramView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Label("Бібліотека вправ", systemImage: "books.vertical")
                    }
                }
                Section {
                    ContentUnavailableView {
                        Label("Програма тренувань", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Тут з'явиться твій тижневий план тренувань.")
                    }
                }
            }
            .navigationTitle("Програма")
        }
    }
}

#Preview {
    ProgramView()
        .previewData()
}
