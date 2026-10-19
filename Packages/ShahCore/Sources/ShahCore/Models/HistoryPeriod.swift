import Foundation

public enum HistoryPeriod: String, CaseIterable, Codable, Sendable {
    case week
    case month
    case year
}

/// A calendar week, month or year, as an inclusive range of days.
public struct PeriodWindow: Hashable, Sendable {
    public let period: HistoryPeriod
    public let start: DayKey
    public let end: DayKey

    /// The week/month/year that contains `day`.
    /// - Parameter firstWeekday: 1 = Sunday, 2 = Monday (from `Calendar.current.firstWeekday`).
    public static func containing(_ day: DayKey, period: HistoryPeriod, firstWeekday: Int) -> PeriodWindow {
        switch period {
        case .week:
            let offset = (day.weekday - firstWeekday + 7) % 7
            let start = day.advanced(by: -offset)
            return PeriodWindow(period: .week, start: start, end: start.advanced(by: 6))
        case .month:
            let start = DayKey(year: day.year, month: day.month, day: 1)
            return PeriodWindow(period: .month, start: start, end: DayKey(year: day.year, month: day.month, day: start.daysInMonth))
        case .year:
            return PeriodWindow(period: .year, start: DayKey(year: day.year, month: 1, day: 1), end: DayKey(year: day.year, month: 12, day: 31))
        }
    }

    /// The window `steps` periods later (negative = earlier).
    public func shifted(by steps: Int, firstWeekday: Int) -> PeriodWindow {
        switch period {
        case .week:
            return .containing(start.advanced(by: 7 * steps), period: .week, firstWeekday: firstWeekday)
        case .month:
            let index = start.year * 12 + (start.month - 1) + steps
            let day = DayKey(year: Int((Double(index) / 12).rounded(.down)), month: ((index % 12) + 12) % 12 + 1, day: 1)
            return .containing(day, period: .month, firstWeekday: firstWeekday)
        case .year:
            return .containing(DayKey(year: start.year + steps, month: 1, day: 1), period: .year, firstWeekday: firstWeekday)
        }
    }

    public func contains(_ day: DayKey) -> Bool {
        start <= day && day <= end
    }

    public var days: [DayKey] {
        DayKey.range(start, through: end)
    }
}
