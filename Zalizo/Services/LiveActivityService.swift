import ActivityKit
import Foundation
import ZalizoCore

/// Rest timer on the lock screen / Dynamic Island. Works only if the widget extension is installed
/// and the user allows Live Activities; otherwise every call is a no-op.
@MainActor
enum LiveActivityService {
    static let enabledKey = "liveActivityEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    private static var current: Activity<RestActivityAttributes>?

    static func start(title: String, startedAt: Date, state: RestActivityAttributes.ContentState) {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if current == nil {
            current = Activity<RestActivityAttributes>.activities.first { $0.attributes.startedAt == startedAt }
        }
        if current != nil {
            update(state)
            return
        }
        do {
            current = try Activity.request(
                attributes: RestActivityAttributes(workoutTitle: title, startedAt: startedAt),
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            Log.ui.error("Live Activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func update(_ state: RestActivityAttributes.ContentState) {
        guard let current else { return }
        Task { await current.update(ActivityContent(state: state, staleDate: state.restEnd)) }
    }

    static func end() {
        let activities = Activity<RestActivityAttributes>.activities
        current = nil
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
