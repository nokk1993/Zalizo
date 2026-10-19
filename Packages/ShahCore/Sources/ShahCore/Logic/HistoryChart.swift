import Foundation

public struct ChartBar: Identifiable, Hashable, Sendable {
    /// The day, or the first day of the month in the year view.
    public let start: DayKey
    /// Day total, or the average per day of that month in the year view, so
    /// the goal line means the same thing in every period.
    public let meters: Double
    public let isFuture: Bool
    public let goalMet: Bool

    public var id: DayKey { start }
}

public struct PeriodSummary: Equatable, Sendable {
    public let totalMeters: Double
    /// Average per counted day; `nil` when no day in the window counts.
    public let averageMeters: Double?
    public let bestDay: DayTotal?
    /// Days up to today and not before the first day with data.
    public let countedDays: Int
}

public enum HistoryChart {
    public static func bars(for window: PeriodWindow, history: History, today: DayKey, goalMeters: Double) -> [ChartBar] {
        switch window.period {
        case .week, .month:
            return window.days.map { day in
                let meters = day > today ? 0 : history[day].meters
                return ChartBar(start: day, meters: meters, isFuture: day > today, goalMet: goalMeters > 0 && meters >= goalMeters)
            }
        case .year:
            return (1...12).map { month in
                let first = DayKey(year: window.start.year, month: month, day: 1)
                let monthWindow = PeriodWindow.containing(first, period: .month, firstWeekday: 1)
                let counted = countedDays(in: monthWindow, history: history, today: today)
                let average = counted.isEmpty ? 0 : counted.reduce(0) { $0 + history[$1].meters } / Double(counted.count)
                return ChartBar(start: first, meters: average, isFuture: first > today, goalMet: goalMeters > 0 && average >= goalMeters)
            }
        }
    }

    public static func summary(for window: PeriodWindow, history: History, today: DayKey) -> PeriodSummary {
        let days = countedDays(in: window, history: history, today: today).map { history[$0] }
        let total = days.reduce(0) { $0 + $1.meters }
        let best = days.filter { $0.meters > 0 }.max { $0.meters < $1.meters }
        return PeriodSummary(
            totalMeters: total,
            averageMeters: days.isEmpty ? nil : total / Double(days.count),
            bestDay: best,
            countedDays: days.count
        )
    }

    static func countedDays(in window: PeriodWindow, history: History, today: DayKey) -> [DayKey] {
        guard let first = history.firstDataDay else { return [] }
        let start = max(window.start, first)
        let end = min(window.end, today)
        return DayKey.range(start, through: end)
    }
}
