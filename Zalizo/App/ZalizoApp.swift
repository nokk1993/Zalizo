import SwiftData
import SwiftUI

@main
struct ZalizoApp: App {
    private let container: ModelContainer?
    private let startupError: String?
    @State private var appState = AppState()

    init() {
        Theme.configureAppearance()
        do {
            let container = try Persistence.makeContainer()
            try Persistence.bootstrap(container.mainContext)
            SeedLoader.seedAll(context: container.mainContext)
            self.container = container
            self.startupError = nil
        } catch {
            self.container = nil
            self.startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .themed()
                    .environment(appState)
                    .modelContainer(container)
            } else {
                StartupErrorView(details: startupError ?? "")
                    .themed()
            }
        }
    }
}

/// Shown only if the database cannot be opened - the app never crashes on startup.
private struct StartupErrorView: View {
    let details: String

    var body: some View {
        ContentUnavailableView {
            Label("Не вдалося відкрити дані", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Спробуй перезапустити додаток. Якщо помилка повторюється - віднови дані з резервної копії в Профілі.")
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .zalScreen()
    }
}
