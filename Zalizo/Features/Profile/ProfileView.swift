import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Профіль", systemImage: "person.crop.circle")
            } description: {
                Text("Тут будуть твої дані, налаштування і резервні копії.")
            }
            .navigationTitle("Профіль")
        }
    }
}

#Preview {
    ProfileView()
        .previewData()
}
