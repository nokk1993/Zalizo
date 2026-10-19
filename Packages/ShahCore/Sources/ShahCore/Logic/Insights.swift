import Foundation

/// How one distance compares to another *as the user sees it*: if the
/// difference rounds to zero at the displayed precision, it is `.same`.
public enum Comparison: Equatable, Sendable {
    case more(meters: Double)
    case less(meters: Double)
    case same

    public init(_ value: Double, versus reference: Double, unit: DistanceUnit, fractionDigits: Int = 1) {
        let scale = pow(10, Double(fractionDigits))
        let diff = value - reference
        let shown = (abs(unit.value(fromMeters: diff)) * scale).rounded() / scale
        if shown == 0 {
            self = .same
        } else {
            self = diff > 0 ? .more(meters: diff) : .less(meters: -diff)
        }
    }
}

public struct TodaySummary: Equatable, Sendable {
    public let day: DayKey
    public let meters: Double
    public let steps: Int
    public let goalMeters: Double
    /// `nil` when there is no history before today (first launch).
    public let yesterdayMeters: Double?
    /// Average of the 7 days before today; `nil` without history.
    public let weekAverageMeters: Double?

    public init(day: DayKey, meters: Double, steps: Int, goalMeters: Double, yesterdayMeters: Double?, weekAverageMeters: Double?) {
        self.day = day
        self.meters = meters
        self.steps = steps
        self.goalMeters = goalMeters
        self.yesterdayMeters = yesterdayMeters
        self.weekAverageMeters = weekAverageMeters
    }

    public var progress: Double { goalMeters > 0 ? meters / goalMeters : 0 }
    public var isGoalMet: Bool { goalMeters > 0 && meters >= goalMeters }
    public var remainingMeters: Double { max(0, goalMeters - meters) }
}

public struct Streak: Equatable, Sendable {
    /// Consecutive days with the goal met, ending today, or yesterday if today
    /// is not met yet (the streak is still alive until the day ends).
    public let current: Int
    public let best: Int
    public let includesToday: Bool

    public static let none = Streak(current: 0, best: 0, includesToday: false)
}

public enum Insights {
    public static func today(_ today: DayKey, history: History, goalMeters: Double) -> TodaySummary {
        let total = history[today]
        var yesterday: Double?
        var average: Double?
        if let first = history.firstDataDay, first < today {
            yesterday = history[today.advanced(by: -1)].meters
            let window = DayKey.range(max(first, today.advanced(by: -7)), through: today.advanced(by: -1))
            if !window.isEmpty {
                average = window.reduce(0) { $0 + history[$1].meters } / Double(window.count)
            }
        }
        return TodaySummary(
            day: today, meters: total.meters, steps: total.steps, goalMeters: goalMeters,
            yesterdayMeters: yesterday, weekAverageMeters: average
        )
    }

    /// The current goal is applied to all past days.
    public static func streak(through today: DayKey, history: History, goalMeters: Double) -> Streak {
        guard goalMeters > 0, let first = history.firstDataDay, first <= today else { return .none }
        func met(_ day: DayKey) -> Bool { history[day].meters >= goalMeters }

        var best = 0
        var run = 0
        for day in DayKey.range(first, through: today) {
            run = met(day) ? run + 1 : 0
            best = max(best, run)
        }

        let todayMet = met(today)
        var current = 0
        var day = todayMet ? today : today.advanced(by: -1)
        while day >= first, met(day) {
            current += 1
            day = day.advanced(by: -1)
        }
        return Streak(current: current, best: best, includesToday: todayMet)
    }
}
