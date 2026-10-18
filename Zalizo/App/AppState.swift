import Observation
import SwiftUI

enum AppTab: Hashable {
    case today, program, progress, nutrition, profile
}

/// App-wide UI state (not persisted).
@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .today
}
