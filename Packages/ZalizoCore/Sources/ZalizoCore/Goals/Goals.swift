import Foundation

/// Progress and forecast for a user goal.
public enum GoalProgress {
    public struct Point: Equatable, Sendable {
        public let date: Date
        public let value: Double

        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    public struct Status: Equatable, Sendable {
        /// 0…1 from start to target.
        public let fraction: Double
        public let current: Double
        public let isAchieved: Bool
        /// Linear forecast from the recent trend (nil if the trend goes the wrong way or there is too little data).
        public let forecastDate: Date?
        /// On track to reach the target before the deadline (nil without a deadline or forecast).
        public let onTrack: Bool?
    }

    /// - Parameter history: values over time (body weight, 1RM estimates, measurements), any order.
    public static func status(start: Double, target: Double, history: [Point], deadline: Date?, now: Date = .now) -> Status {
        let sorted = history.sorted { $0.date < $1.date }
        let current = sorted.last?.value ?? start
        let span = target - start
        let fraction = span == 0 ? 1 : min(max((current - start) / span, 0), 1)
        let achieved = span >= 0 ? current >= target : current <= target
        let forecast = achieved ? now : forecastDate(target: target, history: sorted)
        let onTrack: Bool? = deadline.flatMap { deadline in forecast.map { $0 <= deadline } }
        return Status(fraction: fraction, current: current, isAchieved: achieved, forecastDate: forecast, onTrack: onTrack)
    }

    /// Least-squares slope over the last 8 weeks of data.
    static func forecastDate(target: Double, history: [Point]) -> Date? {
        guard let last = history.last else { return nil }
        let window = history.filter { last.date.timeIntervalSince($0.date) <= 56 * 86_400 }
        guard window.count >= 2, let first = window.first, last.date.timeIntervalSince(first.date) >= 7 * 86_400 else { return nil }
        let xs = window.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = window.map(\.value)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        let numerator = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let denominator = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard denominator > 0 else { return nil }
        let slopePerDay = numerator / denominator
        let remaining = target - last.value
        guard slopePerDay != 0, remaining.sign == slopePerDay.sign else { return nil }
        let days = remaining / slopePerDay
        guard days < 3650 else { return nil }
        return last.date.addingTimeInterval(days * 86_400)
    }

    /// "N тренувань за місяць": workouts in the current calendar month.
    public static func workoutsThisMonth(_ dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        dates.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }.count
    }
}

/// Restrained badges.
public enum AchievementKey: String, CaseIterable, Sendable {
    case firstWorkout
    case workouts10
    case workouts50
    case workouts100
    case streak4Weeks
    case streak12Weeks
    case firstRecord
    case benchBodyweight
    case squatOneAndHalf
    case tonnage100k
    case firstDeload
    case goalReached
}

public enum Achievements {
    public struct Input: Equatable, Sendable {
        public var workouts: Int
        public var bestWeekStreak: Int
        public var records: Int
        public var bodyWeightKg: Double?
        public var bestBenchKg: Double
        public var bestSquatKg: Double
        public var totalTonnage: Double
        public var deloads: Int
        public var goalsReached: Int

        public init(
            workouts: Int = 0, bestWeekStreak: Int = 0, records: Int = 0, bodyWeightKg: Double? = nil,
            bestBenchKg: Double = 0, bestSquatKg: Double = 0, totalTonnage: Double = 0, deloads: Int = 0, goalsReached: Int = 0
        ) {
            self.workouts = workouts
            self.bestWeekStreak = bestWeekStreak
            self.records = records
            self.bodyWeightKg = bodyWeightKg
            self.bestBenchKg = bestBenchKg
            self.bestSquatKg = bestSquatKg
            self.totalTonnage = totalTonnage
            self.deloads = deloads
            self.goalsReached = goalsReached
        }
    }

    public static func unlocked(_ input: Input) -> Set<AchievementKey> {
        var result: Set<AchievementKey> = []
        if input.workouts >= 1 { result.insert(.firstWorkout) }
        if input.workouts >= 10 { result.insert(.workouts10) }
        if input.workouts >= 50 { result.insert(.workouts50) }
        if input.workouts >= 100 { result.insert(.workouts100) }
        if input.bestWeekStreak >= 4 { result.insert(.streak4Weeks) }
        if input.bestWeekStreak >= 12 { result.insert(.streak12Weeks) }
        if input.records >= 1 { result.insert(.firstRecord) }
        if let bodyWeight = input.bodyWeightKg, bodyWeight > 0 {
            if input.bestBenchKg >= bodyWeight { result.insert(.benchBodyweight) }
            if input.bestSquatKg >= bodyWeight * 1.5 { result.insert(.squatOneAndHalf) }
        }
        if input.totalTonnage >= 100_000 { result.insert(.tonnage100k) }
        if input.deloads >= 1 { result.insert(.firstDeload) }
        if input.goalsReached >= 1 { result.insert(.goalReached) }
        return result
    }

    /// Longest run of consecutive ISO weeks with at least `target` workouts.
    public static func bestWeekStreak(_ dates: [Date], target: Int, calendar: Calendar = .iso) -> Int {
        guard target > 0, !dates.isEmpty else { return 0 }
        let weeks = Dictionary(grouping: dates) { calendar.dateInterval(of: .weekOfYear, for: $0)?.start ?? $0 }
            .filter { $0.value.count >= target }
            .keys
            .sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for week in weeks {
            if let previous, let expected = calendar.date(byAdding: .weekOfYear, value: 1, to: previous), calendar.isDate(expected, inSameDayAs: week) {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = week
        }
        return best
    }
}
