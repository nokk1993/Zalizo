import Foundation

/// Personal bests of one exercise, used to flag new records live during a workout.
public struct ExerciseBests: Equatable, Sendable {
    public var maxWeight: Double = 0
    public var estimatedOneRM: Double = 0
    public var setVolume: Double = 0
    /// Heaviest weight lifted for at least N reps, N ∈ `repTargets`.
    public var repMax: [Int: Double] = [:]

    public static let repTargets = [1, 3, 5, 8, 10]

    public init() {}

    public init(sets: [PerformedSet], formula: OneRMFormula = .epley) {
        for set in sets {
            _ = register(set, formula: formula)
        }
    }

    public struct Hit: Equatable, Sendable {
        public let kind: RecordKind
        /// Rep count for `.repMax`, 0 otherwise.
        public let repTarget: Int
        public let value: Double
    }

    /// Updates bests with a new set and returns which records it broke.
    /// The first ever set of an exercise is not reported as a record.
    public mutating func register(_ set: PerformedSet, formula: OneRMFormula = .epley) -> [Hit] {
        guard set.weight >= 0, set.reps > 0 else { return [] }
        let isFirst = maxWeight == 0 && estimatedOneRM == 0 && setVolume == 0 && repMax.isEmpty
        var hits: [Hit] = []
        let e1rm = OneRM.estimate(weight: set.weight, reps: set.reps, formula: formula).value
        let volume = set.weight * Double(set.reps)

        if set.weight > maxWeight + 0.001 {
            maxWeight = set.weight
            hits.append(Hit(kind: .maxWeight, repTarget: 0, value: set.weight))
        }
        if e1rm > estimatedOneRM + 0.001 {
            estimatedOneRM = e1rm
            hits.append(Hit(kind: .estimatedOneRM, repTarget: 0, value: e1rm))
        }
        if volume > setVolume + 0.001 {
            setVolume = volume
            hits.append(Hit(kind: .setVolume, repTarget: 0, value: volume))
        }
        for target in Self.repTargets where set.reps >= target {
            if set.weight > (repMax[target] ?? -1) + 0.001 {
                repMax[target] = set.weight
                hits.append(Hit(kind: .repMax, repTarget: target, value: set.weight))
            }
        }
        return isFirst || set.weight == 0 ? [] : hits
    }
}

/// Rest timer driven by an end date, so it stays correct while the app is suspended.
public struct RestTimer: Equatable, Sendable {
    public private(set) var endDate: Date
    public private(set) var duration: TimeInterval

    public init(start: Date = .now, seconds: Int) {
        duration = TimeInterval(max(0, seconds))
        endDate = start.addingTimeInterval(duration)
    }

    public func remaining(at now: Date = .now) -> TimeInterval {
        max(0, endDate.timeIntervalSince(now))
    }

    public func isFinished(at now: Date = .now) -> Bool { remaining(at: now) <= 0 }

    /// 0…1 elapsed share for the progress ring.
    public func progress(at now: Date = .now) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }

    public mutating func add(seconds: Int, now: Date = .now) {
        if isFinished(at: now) {
            endDate = now.addingTimeInterval(TimeInterval(seconds))
            duration = TimeInterval(seconds)
        } else {
            endDate = endDate.addingTimeInterval(TimeInterval(seconds))
            duration += TimeInterval(seconds)
        }
    }

    /// "1:05"
    public static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Totals for the post-workout summary.
public struct WorkoutStats: Equatable, Sendable {
    public var durationSeconds: Int
    public var tonnage: Double
    public var workingSets: Int
    public var exercises: Int

    public init(durationSeconds: Int, sets: [[Volume.SetSample]]) {
        self.durationSeconds = durationSeconds
        tonnage = sets.reduce(0) { $0 + Volume.tonnage($1) }
        workingSets = sets.reduce(0) { $0 + $1.filter { !$0.isWarmup }.count }
        exercises = sets.filter { !$0.filter { !$0.isWarmup }.isEmpty }.count
    }

    /// Tonnage change in % vs. a previous workout (nil if none).
    public func tonnageChangePercent(vs previous: WorkoutStats?) -> Double? {
        guard let previous, previous.tonnage > 0 else { return nil }
        return (tonnage - previous.tonnage) / previous.tonnage * 100
    }

    /// "1 год 05 хв" style components.
    public var hoursMinutes: (hours: Int, minutes: Int) {
        (durationSeconds / 3600, (durationSeconds % 3600) / 60)
    }
}
