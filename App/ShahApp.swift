import ShahCore
import SwiftUI

@main
struct ShahApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = AppModel.live()
        // Observers must be registered at every launch, including background
        // launches by HealthKit, for background delivery to keep working.
        model.startHealthObservation()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.accent)
                .preferredColorScheme(model.settings.theme.colorScheme)
        }
        // `initial: true` also runs on cold start.
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.isInForeground = phase == .active
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
