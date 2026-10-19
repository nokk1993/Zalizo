#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Shared between the app (starts/updates the activity) and the widget extension (draws it).
public struct RestActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// End of the current rest; nil while a set is in progress.
        public var restEnd: Date?
        public var exerciseName: String
        /// "72,5 кг × 8"
        public var nextSet: String
        public var setsDone: Int
        public var setsTotal: Int

        public init(restEnd: Date?, exerciseName: String, nextSet: String, setsDone: Int, setsTotal: Int) {
            self.restEnd = restEnd
            self.exerciseName = exerciseName
            self.nextSet = nextSet
            self.setsDone = setsDone
            self.setsTotal = setsTotal
        }
    }

    public var workoutTitle: String
    public var startedAt: Date

    public init(workoutTitle: String, startedAt: Date) {
        self.workoutTitle = workoutTitle
        self.startedAt = startedAt
    }
}
#endif
