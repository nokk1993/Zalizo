import Foundation

/// Rough workout duration for "~65 хв" on the Today screen.
public enum SessionEstimate {
    public struct Item: Sendable {
        public let sets: Int
        public let restSeconds: Int
        public let hasWarmup: Bool

        public init(sets: Int, restSeconds: Int, hasWarmup: Bool) {
            self.sets = sets
            self.restSeconds = restSeconds
            self.hasWarmup = hasWarmup
        }
    }

    /// ~40 s per set + planned rest after each set (the last one covers moving to the next exercise)
    /// + 5 min per warmed-up lift + 1 min setup per exercise; rounded to 5 min.
    public static func minutes(_ items: [Item]) -> Int {
        let seconds = items.reduce(0) { total, item in
            let sets = max(0, item.sets)
            return total + sets * 40 + sets * item.restSeconds + (item.hasWarmup ? 300 : 0) + 60
        }
        return max(5, Int((Double(seconds) / 60 / 5).rounded()) * 5)
    }
}
